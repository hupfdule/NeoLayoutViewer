using Gtk;
using Gdk;
using X; //keysym.h
using Posix;//system-calls

namespace NeoLayoutViewer {

	public class Modkey {
		public Gtk.Image modKeyImage;
		public int modifier_index;
		public int active;

		public Modkey(ref Gtk.Image i, int m) {
			this.modKeyImage = i;
			this.modifier_index = m;
			this.active = 0;
		}

		public void change (int new_state) {
			if (new_state == this.active) return;
			this.active = new_state;
			if (this.active == 0) {
				modKeyImage.hide();
			}else{
				modKeyImage.show();
			}
		}
	}

	public class NeoWindow : Gtk.ApplicationWindow {

		private Gtk.Image image;
		public Gtk.Label status;
		private Gdk.Pixbuf[] image_buffer;
		public Gee.List<Modkey> modifier_key_images; // for modifier which didn't toggle a layout layer. I.e. ctrl, alt.
		public Gee.Map<string, string> config;

		public bool fix_layer = false;
		private int _layer = 1;
		public int layer {
			get { return _layer; }
			set { if (value < 1 || value > 6) { _layer = 1; }else{ _layer = value; } }
		}
		public int[] active_modifier_by_keyboard;
		public int[] active_modifier_by_mouse;
		public int numpad_width;
		public int function_keys_height;
		private bool minimized;
		private int position_num;
		private int[] position_cycle;
		private int position_on_hide_x;
		private int position_on_hide_y;
		private int screen_dim[2];
		private bool screen_dim_auto[2]; //if true, x/y screen dimension will detect on every show event.

		/* Die Neo-Modifier unterscheiden sich zum Teil von den Normalen, für die Konstanten definiert sind. Bei der Initialisierung werden aus den Standardkonstanen die Konstanten für die Ebenen 1-6 berechnet.*/
		public int[] NEO_MODIFIER_MASK;
		public int[] MODIFIER_MASK;

		/* Falls ein Modifier (oder eine andere Taste) gedrückt wird und schon Modifier gedrückt sind, gibt die Map an, welche Ebene dann aktiviert ist. */
		private short[,] MODIFIER_MAP = {
			{0, 1, 2, 3, 4, 5},
			{1, 1, 4, 3, 4, 5},
			{2, 4, 2, 5, 4, 5},
			{3, 3, 5, 3, 4, 5} };

		/* [0, 1]^3->{0, 5}, Bildet aktive Modifier auf angezeigte Ebene ab.
			 Interpretationsreihenfolge der Dimensionen: Shift, Neo-Mod3, Neo-Mod4. */
		private short[,,] MODIFIER_MAP2 = {
			{ {0 , 3}, {2 , 5 } },  // 000, 001; 010, 011
			{ {1 , 3}, {4 , 5}}	  // 100, 101; 110, 111
		};

		/* {0, 5} -> [0, 1]^3 */
		private short[,] LAYER_TO_MODIFIERS = {
			{0 , 0, 0}, // 0
			{1 , 0, 0}, // 1
			{0 , 1, 0}, // 2
			{0 , 0, 1}, // 3
			{1 , 1, 0}, // 4
			{1 , 1, 1}  // 5
		};

		/* Analog zu oben für den Fall, dass eine Taste losgelassen wird. Funktioniert nicht immer.
			 Ist beispielsweise ShiftL und ShiftR gedrückt und eine wird losgelassen, so wechselt die Anzeige zur ersten Ebene.
			 Die Fehler sind imo zu vernachlässigen.
		 */
		private short[,] MODIFIER_MAP_RELEASE = {
			{0, 0, 0, 0, 0, 0},
			{0, 0, 2, 3, 2, 5},
			{0, 1, 0, 3, 1, 3},
			{0, 1, 2, 0, 4, 2} };

		/*
			 Modifier können per Tastatur und Maus aktiviert werden. Diese Abbildung entscheidet,
			 wie bei einer Zustandsänderung verfahren werden soll.
			 k, m, K, M ∈ {0, 1}.
			 k - Taste wurde gedrückt gehalten
			 m - Taste wurde per Mausklick selektiert.
			 K - Taste wird gedrückt
			 M - Taste wird per Mausklick selektiert.

			 k' = f(k, m, K, M). Und wegen der Symmetrie(!)
			 m' = f(m, k, M, K)
			 Siehe auch change_active_modifier(…).
		 */
		private short[,,,] MODIFIER_KEYBOARD_MOUSE_MAP = {
			//		 k		=				f(k, m, K, M, ) and m = f(m, k, M, K)
			{ { {0, 0} , {1, 0} } ,  // 0000, 0001; 0010, 0011;
				{ {0, 0} , {1, 1} } }, // 0100, 0101; 0110, 0111(=swap);
			{ { {0, 0} , {1, 0} } , //1000, 1001; 1010, 1011(=swap);
				{ {0, 0} , {1, 1} } }//1100, 1101; 1110, 1111; //k=m=1 should be impossible
		};

		public NeoWindow (NeoLayoutViewerApp app) {
			this.config = app.configm.getConfig();
			this.minimized = true;

			/* Set window type to let tiling window manager the chance
			 * to float the window automatically.
			 */
			//this.type_hint = Gdk.WindowTypeHint.SPLASHSCREEN;
			this.type_hint = Gdk.WindowTypeHint.UTILITY;

			this.NEO_MODIFIER_MASK = {
				0,
				Gdk.ModifierType.SHIFT_MASK, //1
				Gdk.ModifierType.MOD5_MASK+Gdk.ModifierType.LOCK_MASK, //128+2
				Gdk.ModifierType.MOD3_MASK, //32
				Gdk.ModifierType.MOD5_MASK+Gdk.ModifierType.LOCK_MASK+Gdk.ModifierType.SHIFT_MASK, //128+2+1
				Gdk.ModifierType.MOD5_MASK+Gdk.ModifierType.LOCK_MASK+Gdk.ModifierType.MOD3_MASK //128+2+32
			};
			this.MODIFIER_MASK = {
				0,
				Gdk.ModifierType.SHIFT_MASK, //1
				Gdk.ModifierType.MOD5_MASK, //128
				Gdk.ModifierType.MOD3_MASK, //32
				Gdk.ModifierType.CONTROL_MASK,
				Gdk.ModifierType.MOD1_MASK // Alt-Mask do not work :-(
			};
			this.active_modifier_by_keyboard = {0, 0, 0, 0, 0, 0};
			this.active_modifier_by_mouse = {0, 0, 0, 0, 0, 0};

			this.modifier_key_images = new Gee.ArrayList<Modkey>(); 
			this.position_num = int.max(int.min(int.parse(this.config.get("position")), 9), 1);

			//Anlegen des Arrays, welches den Positionsdurchlauf beschreibt.
			try {
				var space = new Regex(" ");
				string[] split = space.split(this.config.get("position_cycle"));
				position_cycle = new int[int.max(9, split.length)];
				for (int i = 0;i < split.length; i++) {
					position_cycle[i] = int.max(int.min(int.parse(split[i]), 9), 1);//Zulässiger Bereich: 1-9
				}
			} catch (RegexError e) {
				position_cycle = {3, 3, 9, 1, 3, 9, 1, 7, 7};
			}

			if (app.start_layer > 0 ){
				this.fix_layer = true;
				this.layer = app.start_layer;
				this.active_modifier_by_mouse[1] = this.LAYER_TO_MODIFIERS[this.layer-1, 0];
				this.active_modifier_by_mouse[2] = this.LAYER_TO_MODIFIERS[this.layer-1, 1];
				this.active_modifier_by_mouse[3] = this.LAYER_TO_MODIFIERS[this.layer-1, 2];
			}

			// Crawl dimensions of screen/display/monitor
		  // Should be done before load_image_buffer() is called.
			screen_dim_auto[0] = (this.config.get("screen_width") == "auto");
			screen_dim_auto[1] = (this.config.get("screen_height") == "auto");

			if (screen_dim_auto[0]) {
				this.screen_dim[0] = this.get_screen_width();
				this.screen_dim_auto[0] = false; // Disables further re-evaluations
			} else {
				this.screen_dim[0] = int.max(1, int.parse(this.config.get("screen_width")));
			}

			if(screen_dim_auto[1]) {
				this.screen_dim[1] = this.get_screen_height();
				this.screen_dim_auto[1] = false; // Disables further re-evaluations
			} else {
				this.screen_dim[1] = int.max(1, int.parse(this.config.get("screen_height")));
			}


			// Load pngs of all six layers
			this.load_image_buffer();
			this.image = new Gtk.Image();//.from_pixbuf(this.image_buffer[layer]);


			image.show();
			render_page();
			var fixed = new Fixed();

			fixed.put(this.image, 0, 0);

#if _NO_WIN
			fixed.put(new KeyOverlay(this), 0, 0);
#endif

			this.status = new Label("");
			status.show();
			int width;
			int height;
			this.get_size2(out width, out height);

			//bad position, if numpad not shown...
			fixed.put( status, (int) ( (0.66)*width), (int) (0.40*height) );

			add(fixed);
			fixed.show();

			//Fenstereigenschaften setzen
			this.key_press_event.connect(on_key_pressed);
			this.button_press_event.connect(on_button_pressed);
			this.destroy.connect(NeoLayoutViewer.quit);

			//this.set_gravity(Gdk.Gravity.SOUTH);
			this.decorated = (this.config.get("window_decoration") != "0");
			this.skip_taskbar_hint = true;

			//Icon des Fensters
			this.icon = this.image_buffer[0];

			//Nicht selektierbar (für virtuelle Tastatur)
			this.set_accept_focus((this.config.get("window_selectable") != "0"));

			if( this.config.get("show_on_startup") != "0" ){
				//Move ist erst nach show() erfolgreich
				this.numkeypad_move(int.parse(this.config.get("position")));
				this.show();
			}else{
				this.hide();
				this.numkeypad_move(int.parse(this.config.get("position")));
			}

		}

		public override void show() {
			this.minimized = false;
			this.move(this.position_on_hide_x, this.position_on_hide_y);
			debug(@"Show window on $(this.position_on_hide_x), $(this.position_on_hide_y)\n");
			base.show();
			this.move(this.position_on_hide_x, this.position_on_hide_y);
			/* Second move fixes issue for i3-wm(?). The move() before show()
				 moves the current window as expected, but somehow does not propagate this values
				 correcty to the wm. => The next hide() call will fetch wrong values
				 and a second show() call plaes the window in the middle of the screen.
			 */

			if (this.config.get("on_top") == "1") {
				this.set_keep_above(true);
			} else {
				this.present();
			}
		}

		public override void hide(){
			//store current coordinates
			int tmpx;
			int tmpy;
			this.get_position(out tmpx, out tmpy);
			this.position_on_hide_x = tmpx;
			this.position_on_hide_y = tmpy;
			debug(@"Hide window on $(this.position_on_hide_x), $(this.position_on_hide_y)\n");

			this.minimized = true;
			base.hide();
		}

		public bool toggle(){
			if(this.minimized) show();
			else hide();
			return this.minimized;
		}

		/* Falsche Werte bei „Tiled Window Managern“. */
		public void get_size2(out int width, out int height){
			width = this.image_buffer[1].width;
			height = this.image_buffer[1].height;
		}

		public void numkeypad_move(int pos){
			int screen_width = this.get_screen_width();
			int screen_height = this.get_screen_height();

			int x, y, w, h;
			this.get_size(out w, out h);

			switch(pos) {
				case 0: //Zur nächsten Position wechseln
					numkeypad_move(this.position_cycle[this.position_num-1]);
					return;
				case 7:
					x = 0;
					y = 0;
					break;
				case 8:
					x = (screen_width - w) / 2;
					y = 0;
					break;
				case 9:
					x = screen_width - w;
					y = 0;
					break;
				case 4:
					x = 0;
					y = (screen_height - h) / 2;
					break;
				case 5:
					x = (screen_width - w) / 2;
					y = (screen_height - h) / 2;
					break;
				case 6:
					x = screen_width - w;
					y = (screen_height - h) / 2;
					break;
				case 1:
					x = 0;
					y = screen_height - h;
					break;
				case 2:
					x = (screen_width - w) / 2;
					y = screen_height - h;
					break;
				default:
					x = screen_width - w;
					y = screen_height - h;
					break;
			}

			this.position_num = pos;

			//store current coordinates
			this.position_on_hide_x = x;
			this.position_on_hide_y = y;


			this.move(x, y);
		}

		public Gdk.Pixbuf open_image (int layer) {
			var bildpfad = @"$(config.get("asset_folder"))/neo2.0/tastatur_neo_Ebene$(layer).png";
			return open_image_str(bildpfad);
		}

		public Gdk.Pixbuf open_image_str (string bildpfad) {
			try {
				return new Gdk.Pixbuf.from_file (bildpfad);
			} catch (Error e) {
				error ("%s", e.message);
			}
		}

		public void load_image_buffer () {
			this.image_buffer = new Gdk.Pixbuf[7];
			this.image_buffer[0] = open_image_str(@"$(config.get("asset_folder"))/icons/Neo-Icon.png");

			int screen_width = this.get_screen_width(); //Gdk.Screen.width();
			int max_width = (int) (double.parse(this.config.get("max_width")) * screen_width);
			int min_width = (int) (double.parse(this.config.get("min_width")) * screen_width);
			int width = int.min(int.max(int.parse(this.config.get("width")), min_width), max_width);
			int w, h;

			this.numpad_width = int.parse(this.config.get("numpad_width"));
			this.function_keys_height = int.parse(this.config.get("function_keys_height"));

			for (int i = 1; i < 7; i++) {
				this.image_buffer[i] = open_image(i);

				//Funktionstasten ausblennden, falls gefordert.
				if (this.config.get("display_function_keys") == "0") {
					var tmp =  new Gdk.Pixbuf(image_buffer[i].colorspace, image_buffer[i].has_alpha, image_buffer[i].bits_per_sample, image_buffer[i].width , image_buffer[i].height-function_keys_height);
					this.image_buffer[i].copy_area(0, function_keys_height, tmp.width, tmp.height, tmp, 0, 0);
					this.image_buffer[i] = tmp;
				}

				//Numpad-Teil abschneiden, falls gefordert.
				if (this.config.get("display_numpad") == "0") {
					var tmp =  new Gdk.Pixbuf(image_buffer[i].colorspace, image_buffer[i].has_alpha, image_buffer[i].bits_per_sample, image_buffer[i].width-numpad_width , image_buffer[i].height);
					this.image_buffer[i].copy_area(0, 0, tmp.width, tmp.height, tmp, 0, 0);
					this.image_buffer[i] = tmp;
				}

				//Bilder einmaling beim Laden skalieren. (Keine spätere Skalierung durch Größenänderung des Fensters)
				w = this.image_buffer[i].width;
				h = this.image_buffer[i].height;
				this.image_buffer[i] = this.image_buffer[i].scale_simple(width, h * width / w, Gdk.InterpType.BILINEAR);
			}

		}

		private bool on_key_pressed (Widget source, Gdk.EventKey key) {
			// If the key pressed was q, quit, else show the next page
			if (key.str == "q") {
				NeoLayoutViewer.quit();
			}

			if (key.str == "h") {
				this.hide();
			}

			return false;
		}

		private bool on_button_pressed (Widget source, Gdk.EventButton event) {
			if (event.button == 3) {
				this.hide();
			}
			return false;
		}

		/*
			 Use the for values
			 - “modifier was pressed”
			 - “modifier is pressed”
			 - “modifier was seleted by mouseclick” and
			 - “modifier is seleted by mouseclick”
			 as array indizes to eval an new state. See comment of MODIFIER_KEYBOARD_MOUSE_MAP, too.
		 */
		public void change_active_modifier(int mod_index, bool keyboard, int new_mod_state) {
			int old_mod_state;
			if (keyboard) {
				//Keypress or Release of shift etc.
				old_mod_state = this.active_modifier_by_keyboard[mod_index]; 
				this.active_modifier_by_keyboard[mod_index] = MODIFIER_KEYBOARD_MOUSE_MAP[
					old_mod_state,
					this.active_modifier_by_mouse[mod_index],
					new_mod_state,
					this.active_modifier_by_mouse[mod_index]
					];
				this.active_modifier_by_mouse[mod_index] = MODIFIER_KEYBOARD_MOUSE_MAP[
					this.active_modifier_by_mouse[mod_index],
					old_mod_state,
					this.active_modifier_by_mouse[mod_index],
					new_mod_state
					];
			} else {
				//Mouseclick on shift button etc.
				old_mod_state = this.active_modifier_by_mouse[mod_index]; 
				this.active_modifier_by_mouse[mod_index] = MODIFIER_KEYBOARD_MOUSE_MAP[
					old_mod_state,
					this.active_modifier_by_keyboard[mod_index],
					new_mod_state,
					this.active_modifier_by_keyboard[mod_index]
						];
				this.active_modifier_by_keyboard[mod_index] = MODIFIER_KEYBOARD_MOUSE_MAP[
					this.active_modifier_by_keyboard[mod_index],
					old_mod_state,
					this.active_modifier_by_keyboard[mod_index],
					new_mod_state
					];
			}

		}

		public int getActiveModifierMask(int[] modifier) {
			int modMask = 0;
			foreach (int i in modifier) {
				modMask += (this.active_modifier_by_keyboard[i] | this.active_modifier_by_mouse[i]) * this.MODIFIER_MASK[i];
			}
			return modMask;
		}

		private void check_modifier(int iet1) {

			if (iet1 != this.layer) {
				this.layer = iet1;
				render_page();
			}
		}

		public void redraw() {
			var tlayer = this.layer;
			if (this.fix_layer) {  // Ignore key events
				this.layer = this.MODIFIER_MAP2[
					this.active_modifier_by_mouse[1], //shift
					this.active_modifier_by_mouse[2], //neo-mod3
					this.active_modifier_by_mouse[3] //neo-mod4
				] + 1;

			}else{
				this.layer = this.MODIFIER_MAP2[
					this.active_modifier_by_keyboard[1] | this.active_modifier_by_mouse[1], //shift
					this.active_modifier_by_keyboard[2] | this.active_modifier_by_mouse[2], //neo-mod3
					this.active_modifier_by_keyboard[3] | this.active_modifier_by_mouse[3] //neo-mod4
				] + 1;
			}
			// check, which extra modifier is pressed and update.
			foreach (var modkey in modifier_key_images) {
				modkey.change(
						this.active_modifier_by_keyboard[modkey.modifier_index] |
						this.active_modifier_by_mouse[modkey.modifier_index]
						);
			}

			if (tlayer != this.layer) {
				render_page();
			}

		}


		private void render_page () {
			this.image.set_from_pixbuf(this.image_buffer[this.layer]);
		}

		public Gdk.Pixbuf getIcon() {
			return this.image_buffer[0];
		}

		public void external_key_press(int iet1, int modifier_mask) {

			for (int iet2 = 0; iet2 < 4; iet2++) {
				if (this.NEO_MODIFIER_MASK[iet2] == modifier_mask) {
					iet1 = this.MODIFIER_MAP[iet1, iet2] + 1;
					this.check_modifier(iet1);
					return;
				}
			}

			iet1 = this.MODIFIER_MAP[iet1, 0] + 1;
			this.check_modifier(iet1);
		}

		public void external_key_release(int iet1, int modifier_mask) {
			for (int iet2 = 0; iet2 < 4; iet2++) {
				if (this.NEO_MODIFIER_MASK[iet2] == modifier_mask) {
					iet1 =  this.MODIFIER_MAP_RELEASE[iet1, iet2] + 1;
					this.check_modifier(iet1);
					return;
				}
			}

			iet1 = this.MODIFIER_MAP_RELEASE[iet1, 0] + 1;
			this.check_modifier(iet1);
		}

		public int get_screen_width(){
			// Return value derived from config.get("screen_width")) or Gdk.Screen.width()

			if( this.screen_dim_auto[0] ){
				//Re-evaluate

#if GTK_MINOR_VERSION == 18 || GTK_MINOR_VERSION == 19 || GTK_MINOR_VERSION == 20 || GTK_MINOR_VERSION == 21
				// Old variant for ubuntu 16.04 ( '<' check not defined in vala preprozessor :-()
				var display = Gdk.Display.get_default();
				var screen = display.get_default_screen();
				//Gdk.Rectangle geometry = {0, 0, screen.get_width(), screen.get_height()};
				screen_dim[0] = screen.get_width();
#else
				var display = Gdk.Display.get_default();
				var screen = this.get_screen();
				var monitor = display.get_monitor_at_window(screen.get_active_window());
				//Note that type of this is Gtk.Window, but get_active_window() return Gdk.Window
				if( monitor == null){
					monitor = display.get_primary_monitor();
				}
				Gdk.Rectangle geometry = monitor.get_geometry();
				screen_dim[0] = geometry.width;
#endif
			}
			return screen_dim[0];
		}

		public int get_screen_height(){
			// Return value derived from config.get("screen_height")) or Gdk.Screen.height()

			if( this.screen_dim_auto[1] ){
				//Re-evaluate

#if GTK_MINOR_VERSION == 18 || GTK_MINOR_VERSION == 19 || GTK_MINOR_VERSION == 20 || GTK_MINOR_VERSION == 21
				// Old variant for ubuntu 16.04 ( '<' check not defined in vala preprozessor :-()
				var display = Gdk.Display.get_default();
				var screen = display.get_default_screen();
				//Gdk.Rectangle geometry = {0, 0, screen.get_width(), screen.get_height()};
				screen_dim[1] = screen.get_height();
#else
				var display = Gdk.Display.get_default();
				var screen = this.get_screen();
				var monitor = display.get_monitor_at_window(screen.get_active_window());
				//Note that type of this is Gtk.Window, but get_active_window() return Gdk.Window
				if( monitor == null){
					monitor = display.get_primary_monitor();
				}
				Gdk.Rectangle geometry = monitor.get_geometry();
				screen_dim[1] = geometry.height;
#endif
			}
			return screen_dim[1];
		}

	} //End class NeoWindow

}
