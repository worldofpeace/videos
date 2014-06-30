// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013-2014 Audience Developers (http://launchpad.net/pantheon-chat)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * Authored by: Tom Beckmann <tomjonabc@gmail.com>
 */

namespace Audience.Widgets {
    public class Playlist : Gtk.TreeView {
        // the player is requested to play path
        public signal void play (File path);

        private enum Columns {
            PLAYING,
            TITLE,
            FILENAME,
            N_COLUMNS
        }

        private int current = 0;
        private Gtk.ListStore playlist;

        public Playlist () {
            this.playlist = new Gtk.ListStore (Columns.N_COLUMNS, typeof (Icon), typeof (string), typeof (string));
            this.model = this.playlist;
            this.expand = true;
            this.headers_visible = false;
            this.activate_on_single_click = true;
            this.can_focus = false;
            get_selection ().mode = Gtk.SelectionMode.NONE;

            var text_render = new Gtk.CellRendererText ();
            text_render.ellipsize = Pango.EllipsizeMode.END;

            this.insert_column_with_attributes (-1, "Playing", new Gtk.CellRendererPixbuf (), "gicon", Columns.PLAYING);
            this.insert_column_with_attributes (-1, "Title", text_render, "text", Columns.TITLE);

            this.row_activated.connect ((path ,col) => {
                Gtk.TreeIter iter;
                playlist.get_iter (out iter, path);
                string filename;
                playlist.get (iter, Columns.FILENAME, out filename);
                play (File.new_for_commandline_arg (filename));
                change_current_symbol (iter);
                this.current = int.parse (path.to_string ());
            });

            this.reorderable = true;
            this.model.row_inserted.connect ((path, iter) => {
                Gtk.TreeIter it;
                playlist.get_iter (out it, path);
                Gdk.Pixbuf playing;
                playlist.get (it, Columns.PLAYING, out playing);
                if (playing != null) //if playing is not null it's the current item
                    this.current = int.parse (path.to_string ());
            });
        }

        private inline void change_current_symbol (Gtk.TreeIter new_item) {
            Gtk.TreeIter old_item;
            playlist.get_iter_from_string (out old_item, this.current.to_string ());
            playlist.set (old_item, Columns.PLAYING, null);
            playlist.set (new_item, Columns.PLAYING, new ThemedIcon ("media-playback-start-symbolic"));
        }

        public void next () {
            Gtk.TreeIter iter;
            if (playlist.get_iter_from_string (out iter, (this.current + 1).to_string ())){
                string filename;
                playlist.get (iter, Columns.FILENAME, out filename);
                change_current_symbol (iter);
                current++;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void previous () {
            Gtk.TreeIter iter;
            if (playlist.get_iter_from_string (out iter, (this.current - 1).to_string ())){
                string filename;
                playlist.get (iter, Columns.FILENAME, out filename);
                change_current_symbol (iter);
                current--;
                play (File.new_for_commandline_arg (filename));
            }
        }

        public void add_item (File path) {
            Gtk.TreeIter iter;

            Icon? playing = null;
            Gtk.TreeIter dummy;
            if (!playlist.get_iter_first (out dummy)){
                playing = new ThemedIcon ("media-playback-start-symbolic");
            } else {
                playing = null;
            }

            playlist.append (out iter);
            playlist.set (iter, Columns.PLAYING, playing,
                                Columns.TITLE, Audience.get_title (path.get_basename ()),
                                Columns.FILENAME, path.get_path ());
        }

        public void remove_item (File path) {
            /*not needed up to now*/
        }

        public File? get_first_item () {
            Gtk.TreeIter iter;
            if (playlist.get_iter_first (out iter)){
                string filename;
                playlist.get (iter, Columns.FILENAME, out filename);
                return File.new_for_commandline_arg (filename);
            }
            return null;
        }

        public List<string> get_all_items () {
            var list = new List<string> ();
            playlist.foreach ((model, path, iter) => {
                Value filename;
                playlist.get_value (iter, Columns.FILENAME, out filename);
                string name = filename.get_string ();
                list.append (name);
                return false;
            });
            return list.copy ();
        }

        public void save_playlist_config () {
            var list = new List<string> ();
            playlist.foreach ((model, path, iter) => {
                Value filename;
                playlist.get_value (iter, Columns.FILENAME, out filename);
                string name = filename.get_string ();
                list.append (name);
                return false;
            });

            uint i = 0;
            //settings.last_played_videos = new string[list.length ()];
            foreach (var filename in list) {
                settings.last_played_videos[i] = filename;
                i++;
            }
        }

    }

}