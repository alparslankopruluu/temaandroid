package com.screenmotion.studio.scene

import com.screenmotion.studio.model.InteractionProfile
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

data class SceneVector(val x: Double, val y: Double) {
    fun bounded() = SceneVector(x.coerceIn(-1.0, 1.0), y.coerceIn(-1.0, 1.0))
    operator fun plus(other: SceneVector) = SceneVector(x + other.x, y + other.y)
    operator fun minus(other: SceneVector) = SceneVector(x - other.x, y - other.y)
    operator fun times(scale: Double) = SceneVector(x * scale, y * scale)
    fun normalized(): SceneVector {
        val length = sqrt(x * x + y * y)
        return if (length <= .000001) ZERO else SceneVector(x / length, y / length)
    }

    companion object { val ZERO = SceneVector(0.0, 0.0) }
}

data class SceneInput(
    val tilt: SceneVector = SceneVector.ZERO,
    val drag: SceneVector? = null,
    val tap: SceneVector? = null,
)

data class SceneObstacle(val id: ULong, var position: SceneVector, val radius: Double)

data class InteractiveState(
    var position: SceneVector,
    var velocity: SceneVector = SceneVector.ZERO,
    var rotation: Double = 0.0,
    var tapResponse: Double = 0.0,
    var score: Int = 0,
    var highScore: Int = 0,
    var elapsed: Double = 0.0,
    var run: ULong = 0u,
)

sealed interface SceneEvent {
    data class ScoreChanged(val score: Int) : SceneEvent
    data class HighScoreChanged(val score: Int) : SceneEvent
    data class Collision(val obstacleId: ULong) : SceneEvent
    data object TapResponded : SceneEvent
}

class InteractiveSceneBehavior(
    val profile: InteractionProfile,
    private var scoreMode: Boolean,
    private val seed: ULong,
    highScore: Int = 0,
) {
    var state = InteractiveState(initialPosition(profile), highScore = highScore.coerceAtLeast(0))
        private set
    var obstacles = emptyList<SceneObstacle>()
        private set
    private var random = SeededGenerator(seed)
    private var scoreDistance = 0.0

    init { obstacles = makeObstacles(6) }

    val scoreActive: Boolean
        get() = scoreMode && profile in setOf(
            InteractionProfile.CAR,
            InteractionProfile.MOTORCYCLE,
            InteractionProfile.HELICOPTER,
            InteractionProfile.SPACESHIP,
            InteractionProfile.UFO,
            InteractionProfile.RACE,
        )

    fun setScoreMode(value: Boolean) {
        if (scoreMode != value) {
            scoreMode = value
            reset()
        }
    }

    fun snapshot() = SceneSnapshot(
        position = state.position,
        rotation = state.rotation,
        score = state.score,
        highScore = state.highScore,
        tapResponse = state.tapResponse,
        obstacles = obstacles.map(SceneObstacle::copy),
    )

    fun update(deltaTime: Double, time: Double, input: SceneInput = SceneInput()): List<SceneEvent> {
        val delta = deltaTime.coerceIn(0.0, 0.1)
        state.elapsed += delta
        state.tapResponse = (state.tapResponse - delta * 2.4).coerceAtLeast(0.0)
        val events = mutableListOf<SceneEvent>()
        applyInput(input, delta, time, events)
        state.position = (state.position + state.velocity * delta).bounded()
        if (!scoreActive) {
            state.score = 0
            return events
        }
        val previous = state.score
        scoreDistance += delta * forwardSpeed
        state.score = (scoreDistance * 10).toInt()
        if (previous != state.score) events += SceneEvent.ScoreChanged(state.score)
        advanceObstacles(delta)
        obstacles.firstOrNull(::collides)?.let { obstacle ->
            events += SceneEvent.Collision(obstacle.id)
            if (state.score > state.highScore) {
                state.highScore = state.score
                events += SceneEvent.HighScoreChanged(state.highScore)
            }
            reset()
        }
        return events
    }

    private fun applyInput(
        input: SceneInput,
        delta: Double,
        time: Double,
        events: MutableList<SceneEvent>,
    ) {
        val direction = input.drag ?: input.tilt
        val response = (delta * responsiveness).coerceAtMost(1.0)
        when (profile) {
            InteractionProfile.CAR, InteractionProfile.RACE -> {
                state.velocity = SceneVector(
                    state.velocity.x + (direction.x * 1.25 - state.velocity.x) * response,
                    0.0,
                )
                state.position = SceneVector(state.position.x, -.68)
                state.rotation = direction.x * .08
            }
            InteractionProfile.MOTORCYCLE -> {
                state.velocity = SceneVector(
                    state.velocity.x + (direction.x * 1.4 - state.velocity.x) * response,
                    0.0,
                )
                state.position = SceneVector(state.position.x, -.68)
                state.rotation = direction.x * .28
            }
            InteractionProfile.HELICOPTER, InteractionProfile.SPACESHIP, InteractionProfile.UFO -> {
                val xSpeed = when (profile) {
                    InteractionProfile.HELICOPTER -> .95
                    InteractionProfile.UFO -> .72
                    else -> 1.05
                }
                val ySpeed = when (profile) {
                    InteractionProfile.HELICOPTER -> .8
                    InteractionProfile.UFO -> .45
                    else -> .7
                }
                var y = state.velocity.y + (direction.y * ySpeed - state.velocity.y) * response
                if (input.tap != null) y = (y + when (profile) {
                    InteractionProfile.HELICOPTER -> .55
                    InteractionProfile.UFO -> .24
                    else -> .38
                }).coerceAtMost(1.0)
                state.velocity = SceneVector(
                    state.velocity.x + (direction.x * xSpeed - state.velocity.x) * response,
                    y,
                )
                state.rotation = direction.x * if (profile == InteractionProfile.HELICOPTER) .18 else .22
            }
            InteractionProfile.FISH, InteractionProfile.AQUARIUM, InteractionProfile.KOI -> {
                val ambient = SceneVector(sin(time * .7) * .16, cos(time * .45) * .08)
                val target = direction * .45 + ambient
                state.velocity = SceneVector(
                    state.velocity.x + (target.x - state.velocity.x) * response,
                    state.velocity.y + (target.y - state.velocity.y) * response,
                )
                input.tap?.let { state.velocity = (state.velocity + (state.position - it).normalized() * .65).bounded() }
                state.rotation = state.velocity.y * .12
            }
            InteractionProfile.NATURE, InteractionProfile.AUTUMN, InteractionProfile.SNOW -> {
                val breeze = SceneVector(
                    sin(time * if (profile == InteractionProfile.SNOW) .28 else .8) * .08,
                    cos(time * .35) * .04,
                )
                val target = direction * if (profile == InteractionProfile.AUTUMN) .3 else .16
                val wind = target + breeze
                state.velocity = SceneVector(
                    state.velocity.x + (wind.x - state.velocity.x) * response,
                    state.velocity.y + (wind.y - state.velocity.y) * response,
                )
                state.rotation = sin(time * .8) * .025 + direction.x * .035
            }
        }
        if (input.tap != null) {
            state.tapResponse = 1.0
            events += SceneEvent.TapResponded
        }
    }

    private fun advanceObstacles(delta: Double) {
        obstacles.forEach {
            var y = it.position.y - forwardSpeed * delta
            var x = it.position.x
            if (y < -1.25) {
                x = laneValue()
                y = (obstacles.maxOfOrNull { obstacle -> obstacle.position.y } ?: .5) + nextSpacing()
            }
            it.position = SceneVector(x, y)
        }
    }

    private fun collides(obstacle: SceneObstacle): Boolean {
        val offset = state.position - obstacle.position
        return abs(offset.x) <= obstacle.radius + playerRadius &&
            abs(offset.y) <= obstacle.radius + playerRadius
    }

    private fun reset() {
        state = state.copy(
            position = initialPosition(profile),
            velocity = SceneVector.ZERO,
            rotation = 0.0,
            tapResponse = 0.0,
            score = 0,
            elapsed = 0.0,
            run = state.run + 1u,
        )
        scoreDistance = 0.0
        random = SeededGenerator(seed + state.run * 0x9E3779B97F4A7C15u)
        obstacles = makeObstacles(6, (state.run + 1u) * 1_000u)
    }

    private fun makeObstacles(count: Int, offset: ULong = 0u): List<SceneObstacle> {
        var y = .35
        return List(count) { index ->
            y += nextSpacing()
            SceneObstacle(
                id = offset + index.toULong(),
                position = SceneVector(laneValue(), y),
                radius = if (profile == InteractionProfile.MOTORCYCLE) .1 else .13,
            )
        }
    }

    private fun laneValue() = listOf(-.62, 0.0, .62)[random.nextIndex(3)]
    private fun nextSpacing() = .62 + random.nextUnit() * .42
    private val forwardSpeed get() = when (profile) {
        InteractionProfile.CAR, InteractionProfile.RACE -> .78
        InteractionProfile.MOTORCYCLE -> .86
        InteractionProfile.HELICOPTER -> .66
        InteractionProfile.SPACESHIP, InteractionProfile.UFO -> .74
        InteractionProfile.FISH, InteractionProfile.NATURE, InteractionProfile.AQUARIUM,
        InteractionProfile.AUTUMN, InteractionProfile.KOI, InteractionProfile.SNOW -> 0.0
    }
    private val responsiveness get() = when (profile) {
        InteractionProfile.CAR -> 8.0
        InteractionProfile.MOTORCYCLE -> 10.0
        InteractionProfile.HELICOPTER, InteractionProfile.SPACESHIP, InteractionProfile.UFO -> 7.0
        InteractionProfile.FISH, InteractionProfile.AQUARIUM, InteractionProfile.KOI -> 5.0
        InteractionProfile.NATURE, InteractionProfile.AUTUMN, InteractionProfile.SNOW -> 3.0
        InteractionProfile.RACE -> 8.0
    }
    private val playerRadius get() = when (profile) {
        InteractionProfile.MOTORCYCLE -> .08
        InteractionProfile.CAR, InteractionProfile.HELICOPTER, InteractionProfile.SPACESHIP,
        InteractionProfile.UFO, InteractionProfile.RACE -> .11
        else -> 0.0
    }

    companion object {
        fun initialPosition(profile: InteractionProfile) = when (profile) {
            InteractionProfile.CAR, InteractionProfile.MOTORCYCLE, InteractionProfile.RACE -> SceneVector(0.0, -.68)
            else -> SceneVector.ZERO
        }

        fun seed(value: String): ULong =
            value.encodeToByteArray().fold(1_469_598_103_934_665_603uL) { current, byte ->
                (current xor byte.toUByte().toULong()) * 1_099_511_628_211uL
            }
    }
}

private class SeededGenerator(seed: ULong) {
    private var state = if (seed == 0uL) 0xA5A5A5A5A5A5A5A5uL else seed
    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var value = state
        value = (value xor (value shr 30)) * 0xBF58476D1CE4E5B9uL
        value = (value xor (value shr 27)) * 0x94D049BB133111EBuL
        return value xor (value shr 31)
    }
    fun nextUnit() = (next() shr 11).toDouble() / (1uL shl 53).toDouble()
    fun nextIndex(upperBound: Int) = (next() % upperBound.toULong()).toInt()
}
