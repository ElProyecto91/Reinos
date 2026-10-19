package com.reinos.juego;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageInstaller;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;

import androidx.annotation.NonNull;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Instalador de actualizaciones de Reinos. Lo único que hace: coger un APK que el juego ya ha descargado y verificado (SHA-256)
 * y entregárselo al instalador de Android con PackageInstaller. Android sigue pidiendo el toque en «Instalar» y solo acepta
 * un APK firmado con la misma clave que el instalado, de modo que un APK manipulado no puede sustituir al juego.
 *
 * Desde GDScript: Engine.get_singleton("ReinosInstaller") con canInstall(), openInstallSettings(), install(ruta) y status().
 * No toca la red ni ningún otro archivo; solo lee el APK que se le indica.
 */
public class InstallerPlugin extends GodotPlugin {
	private static final String TAG = "ReinosInstaller";
	private static final String ACTION = "com.reinos.juego.INSTALL_STATUS";

	/** "", "pendiente", "confirmar" (el instalador de Android está pidiendo el toque), "ok" o "error:<código>:<mensaje>" */
	private volatile String lastStatus = "";
	private BroadcastReceiver receiver;

	public InstallerPlugin(Godot godot) {
		super(godot);
	}

	@NonNull
	@Override
	public String getPluginName() {
		return "ReinosInstaller";
	}

	/** ¿Tiene la app el permiso «instalar apps desconocidas» (Android 8+)? */
	@UsedByGodot
	public boolean canInstall() {
		Activity act = getActivity();
		if (act == null) {
			return false;
		}
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
			return true;
		}
		return act.getPackageManager().canRequestPackageInstalls();
	}

	/** Abre la pantalla de ajustes donde se concede «Permitir de esta fuente» a Reinos. */
	@UsedByGodot
	public void openInstallSettings() {
		Activity act = getActivity();
		if (act == null) {
			return;
		}
		try {
			Intent i = new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + act.getPackageName()));
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			act.startActivity(i);
		} catch (Exception e) {
			Log.e(TAG, "openInstallSettings", e);
		}
	}

	/** Estado de la última instalación (ver lastStatus). */
	@UsedByGodot
	public String status() {
		return lastStatus;
	}

	/**
	 * Entrega el APK al instalador de Android. Devuelve "" si lo ha entregado, "permiso" si falta el permiso de instalar
	 * apps desconocidas (se abren los ajustes) o "error:..." con el motivo.
	 */
	@UsedByGodot
	public String install(String apkPath) {
		try {
			Activity act = getActivity();
			if (act == null) {
				return "error:sin actividad";
			}
			File f = new File(apkPath);
			if (!f.isFile() || f.length() < 1024) {
				return "error:el archivo no existe o es demasiado pequeño";
			}
			if (!canInstall()) {
				openInstallSettings();
				return "permiso";
			}
			registerReceiverOnce(act);
			PackageInstaller pi = act.getPackageManager().getPackageInstaller();
			PackageInstaller.SessionParams params = new PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL);
			params.setSize(f.length());
			int id = pi.createSession(params);
			PackageInstaller.Session session = pi.openSession(id);
			try {
				InputStream in = new FileInputStream(f);
				try {
					OutputStream out = session.openWrite("base.apk", 0, f.length());
					try {
						byte[] buf = new byte[1 << 16];
						int n;
						while ((n = in.read(buf)) > 0) {
							out.write(buf, 0, n);
						}
						session.fsync(out);
					} finally {
						out.close();
					}
				} finally {
					in.close();
				}
				Intent cb = new Intent(ACTION).setPackage(act.getPackageName());
				int flags = PendingIntent.FLAG_UPDATE_CURRENT;
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					flags |= PendingIntent.FLAG_MUTABLE;   // el sistema añade extras (estado, intent de confirmación)
				}
				PendingIntent pend = PendingIntent.getBroadcast(act, id, cb, flags);
				lastStatus = "pendiente";
				session.commit(pend.getIntentSender());
			} finally {
				session.close();
			}
			return "";
		} catch (Exception e) {
			Log.e(TAG, "install", e);
			lastStatus = "error:" + e;
			return "error:" + e;
		}
	}

	private void registerReceiverOnce(Activity act) {
		if (receiver != null) {
			return;
		}
		receiver = new BroadcastReceiver() {
			@Override
			public void onReceive(Context ctx, Intent intent) {
				int status = intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -1);
				String msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE);
				Log.i(TAG, "estado " + status + " " + msg);
				if (status == PackageInstaller.STATUS_PENDING_USER_ACTION) {
					Intent confirm = getConfirmIntent(intent);
					if (confirm != null) {
						confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
						try {
							ctx.startActivity(confirm);
							lastStatus = "confirmar";
						} catch (Exception e) {
							lastStatus = "error:no se pudo abrir el instalador:" + e;
						}
					} else {
						lastStatus = "error:el sistema no dio la pantalla de confirmación";
					}
				} else if (status == PackageInstaller.STATUS_SUCCESS) {
					lastStatus = "ok";
				} else {
					lastStatus = "error:" + status + ":" + msg;
				}
			}
		};
		IntentFilter filter = new IntentFilter(ACTION);
		Context app = act.getApplicationContext();
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			app.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED);
		} else {
			app.registerReceiver(receiver, filter);
		}
	}

	@SuppressWarnings("deprecation")
	private static Intent getConfirmIntent(Intent intent) {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
			return intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent.class);
		}
		return intent.getParcelableExtra(Intent.EXTRA_INTENT);
	}
}
