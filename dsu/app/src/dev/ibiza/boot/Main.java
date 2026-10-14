package dev.ibiza.boot;

import android.app.Activity;
import android.app.AlertDialog;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStreamReader;

public class Main extends Activity {
    private TextView status;

    private String su(String cmd) {
        try {
            Process p = Runtime.getRuntime().exec(new String[] {"su", "-c", cmd});
            BufferedReader r = new BufferedReader(new InputStreamReader(p.getInputStream()));
            StringBuilder sb = new StringBuilder();
            String l;
            while ((l = r.readLine()) != null) sb.append(l).append(' ');
            p.waitFor();
            return sb.toString().trim();
        } catch (Exception e) {
            return "error: " + e.getMessage();
        }
    }

    private void refresh() {
        new Thread(() -> {
            String s = su("gsi_tool status");
            runOnUiThread(() -> status.setText("DSU: " + (s.isEmpty() ? "unknown (no root?)" : s)));
        }).start();
    }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout v = new LinearLayout(this);
        v.setOrientation(LinearLayout.VERTICAL);
        v.setGravity(Gravity.CENTER);
        v.setPadding(48, 48, 48, 48);
        status = new TextView(this);
        status.setTextSize(16);
        Button go = new Button(this);
        go.setText("Reboot into Debian (one-shot)");
        go.setOnClickListener(x -> new AlertDialog.Builder(this)
            .setMessage("Reboot now into Debian? The next reboot returns to Android.")
            .setPositiveButton("Reboot", (d, w) -> new Thread(() -> {
                String s = su("gsi_tool enable -s && sync && reboot");
                runOnUiThread(() -> status.setText(s));
            }).start())
            .setNegativeButton("Cancel", null).show());
        v.addView(status);
        v.addView(go);
        setContentView(v);
        refresh();
    }
}
