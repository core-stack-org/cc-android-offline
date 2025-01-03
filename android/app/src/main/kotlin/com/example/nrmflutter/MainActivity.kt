package com.example.nrmflutter

import io.flutter.embedding.android.FlutterActivity
import android.webkit.WebView
import android.os.Bundle


class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WebView.setWebContentsDebuggingEnabled(true)
    }
}
