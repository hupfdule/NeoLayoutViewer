using X;

namespace NeoLayoutViewer{

	public ConfigManager configm;
	public NeoLayoutViewerApp app;

	public static int main(string[] args) {

		string[] paths = {
			GLib.Environment.get_user_config_dir(),
			GLib.Environment.get_home_dir(),
			GLib.Environment.get_current_dir(),
		};

		configm = new ConfigManager(paths, "neo_layout_viewer.conf");

		// Try to find asset folder (images)
		string asset_folder = search_asset_folder( configm.getConfig().get("asset_folder") );
		if( asset_folder == null ){
			stdout.printf(@"Application start failed because asset folder was not found.\nTry to set path manually in the config file '$(configm.used_config_path)'\n");
			stdout.flush();
			return 0;
		}

		// Update asset folder in config
		configm.getConfig().set("asset_folder", asset_folder);
		debug(@"Asset folder: $(asset_folder)\n");

		// Init application window.
		app = new NeoLayoutViewerApp (configm);

		try {
			app.register(); // returns false if and only if throws Error
		} catch (Error e) {
			debug(@"Gtk.Application.register() failed.\n");
			return -1;
		}
		if (app.is_remote) {
			print(@"Application is already running.\n");
			app.activate();
		}else{
			return app.run(args);
		}

		return 0;
	}

	private static void quit() {
		app.quit(); // stops app.run()
	}

	private static void about_dialog() {
		/* This function create the about dialog in
			 tray menu or indicator menu */
		var about = new Gtk.AboutDialog();
		about.set_logo(app.neo_win.getIcon());
		about.set_destroy_with_parent (true);
		about.set_transient_for (app.neo_win);
		about.set_version(@"$(RELEASE_VERSION) (git $(GIT_COMMIT_VERSION)) )");
		about.set_program_name("Neo2.0 Ebenenanzeige");
		about.set_comments("""Erleichtert das Nachschlagen von Tastenkombinationen im Neo 2.0-Layout.

 Olaf Schulz
 funwithkinect@googlemail.com


Tastenkombinationen:
 Ein-/Ausblenden - %s
 Bewegen - %s
 Beenden (sofern Fenster selektiert) - q

 Verwendete Konfigurationsdatei:
 %s""".printf(
				app.neo_win.config.get("show_shortcut"),
				app.neo_win.config.get("move_shortcut"),
				configm.used_config_path)
				);
		about.set_copyright("LGPLv3");
		center_window(about);
		about.run();
		about.hide();
		about.destroy();

	}

	private void center_window(Gtk.Window win){
		int screen_width = app.neo_win.get_screen_width();
		int screen_height = app.neo_win.get_screen_height();
		int x, y, w, h;
		win.get_size(out w, out h);
		x = (screen_width - w) / 2;
		y = (screen_height - h) / 2;
		win.move(x, y);
	}

	/* Check given path and shared files folders for the asset folder.
		 The folder will be assumed as right one if one required file was found.
		 @return: assed folder or null.
	 */
	private static string? search_asset_folder(string path){
		/*const*/ string filename = "/icons/Neo-Icon.png";

		string[] paths = {
			path, // path from config file
			"./assets",
			"../assets",
			SHARED_ASSETS_PATH, // path given by Makefile
		};

		foreach( var p in paths ){
			debug(@"Search assets in $(p)\n");
			var file = File.new_for_path (p+filename);
			if( file.query_exists(null)) return p;
		}

		var datadirs = GLib.Environment.get_system_data_dirs();
		foreach( var s in datadirs ){
			var env_path = s + "/NeoLayoutViewer/assets";
			debug(@"Search assets in $(env_path)\n");
			var file2 = File.new_for_path (env_path+filename);
			if( file2.query_exists(null)) return env_path;
		}

		return null;
	}


}

#if _NO_WIN
/* Extern C routines */
extern int keysend(uint keysym, int modifiers);
extern int keysend2(uint keysym, uint modsym1, uint modsym2);
extern bool checkCapsLock(X.Display* d);
extern void checkModifier(X.Display* d, int* keycodes, int nkeycodes, int* pressed );
#endif
