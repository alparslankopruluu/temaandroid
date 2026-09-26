package com.screenmotion.studio.scene

import com.screenmotion.studio.model.InteractionProfile
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InteractiveSceneBehaviorTest {
    @Test fun identicalSeedsProduceIdenticalRuns() {
        val first = InteractiveSceneBehavior(InteractionProfile.CAR, true, 42u)
        val second = InteractiveSceneBehavior(InteractionProfile.CAR, true, 42u)
        repeat(120) { frame ->
            val input = SceneInput(tilt = SceneVector((frame % 7 - 3) / 3.0, 0.0))
            first.update(1.0 / 60.0, frame / 60.0, input)
            second.update(1.0 / 60.0, frame / 60.0, input)
        }
        assertEquals(first.state, second.state)
        assertEquals(first.obstacles, second.obstacles)
    }

    @Test fun everyProfileStaysInsideNormalizedBounds() {
        InteractionProfile.entries.forEach { profile ->
            val behavior = InteractiveSceneBehavior(profile, false, 7u)
            repeat(300) { frame ->
                behavior.update(.1, frame / 10.0, SceneInput(tilt = SceneVector(9.0, -9.0)))
                assertTrue(behavior.state.position.x in -1.0..1.0)
                assertTrue(behavior.state.position.y in -1.0..1.0)
            }
        }
    }

    @Test fun fishAndNatureNeverEnableScore() {
        listOf(
            InteractionProfile.FISH, InteractionProfile.NATURE, InteractionProfile.AQUARIUM,
            InteractionProfile.AUTUMN, InteractionProfile.KOI, InteractionProfile.SNOW,
        ).forEach { profile ->
            val behavior = InteractiveSceneBehavior(profile, true, 99u)
            assertFalse(behavior.scoreActive)
            repeat(60) { behavior.update(1.0 / 60.0, it / 60.0) }
            assertEquals(0, behavior.state.score)
        }
    }

    @Test fun ufoAndRaceProfilesSupportScoreMode() {
        listOf(InteractionProfile.UFO, InteractionProfile.RACE).forEach { profile ->
            val behavior = InteractiveSceneBehavior(profile, true, 101u)
            repeat(60) { behavior.update(1.0 / 60.0, it / 60.0) }
            assertTrue("$profile should enable score", behavior.scoreActive)
            assertTrue("$profile should advance score", behavior.state.score > 0 || behavior.state.highScore > 0)
        }
    }

    @Test fun scoreModeResetsStateWhenToggled() {
        val behavior = InteractiveSceneBehavior(InteractionProfile.SPACESHIP, true, 5u)
        repeat(30) { behavior.update(1.0 / 30.0, it / 30.0) }
        assertTrue(behavior.state.score > 0)
        behavior.setScoreMode(false)
        assertEquals(0, behavior.state.score)
        assertFalse(behavior.scoreActive)
    }
}
