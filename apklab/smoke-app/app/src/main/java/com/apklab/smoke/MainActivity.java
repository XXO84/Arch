package com.apklab.smoke;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.Gravity;
import android.widget.TextView;

public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        TextView view = new TextView(this);
        view.setGravity(Gravity.CENTER);
        view.setTextSize(24f);
        view.setText("APKLab runtime PASS");
        setContentView(view);
        Log.i("APKLAB", "APKLab Smoke launched");
    }
}
