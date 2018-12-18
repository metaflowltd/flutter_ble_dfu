package com.metaflow.bledfu

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.content.ComponentName


class NotificationActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d("NotificationActivity", "onCreate")

        // If this activity is the root activity of the task, the app is not running
        if (isTaskRoot) {
            // Start the app before finishing
            val intent = Intent()
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            intent.putExtras(getIntent().extras!!) // copy all extras
            intent.component = ComponentName("com.metaflow.lumen", "com.metaflow.lumen.MainActivity")
            startActivity(intent)
        }

        // Now finish, which will drop you to the activity at which you were at the top of the task stack
        finish()
    }
}