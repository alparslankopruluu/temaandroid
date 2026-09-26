package com.screenmotion.studio

import com.google.firebase.auth.FirebaseAuth
import kotlinx.coroutines.tasks.await

class FirebaseIdentityService {
    private val auth by lazy { FirebaseAuth.getInstance() }

    suspend fun userId(): String = auth.currentUser?.uid ?: auth.signInAnonymously().await().user
        ?.uid ?: error("Anonymous Firebase user missing")
}
