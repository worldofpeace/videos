// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2016-2016 elementary LLC.
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
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 *
 */

namespace Audience.Services {
    public const int POSTER_WIDTH = 170;
    public const int POSTER_HEIGHT = 240;

    public class LibraryManager : Object {

        public signal void video_file_detected (Audience.Objects.Video video);
        public signal void video_file_deleted (string path);
        public signal void video_folder_deleted (string path);
        public signal void finished ();

        public Regex regex_year { get; construct set; }
        public DbusThumbnailer thumbler { get; construct set; }

        public bool has_items { get; private set; }

        private Gee.ArrayList<string> poster_hash;
        private Gee.ArrayList<FileMonitor> monitoring_directories;

        public static LibraryManager instance = null;
        public static LibraryManager get_instance () {
            if (instance == null) {
                instance = new LibraryManager ();
            }

            return instance;
        }

        private LibraryManager () {
        }

        construct {
            poster_hash = new Gee.ArrayList<string> ();
            monitoring_directories = new Gee.ArrayList<FileMonitor> ();
            try {
                regex_year = new Regex ("\\(\\d\\d\\d\\d(?=(\\)$))");
            } catch (Error e) {
                error (e.message);
            }
            thumbler = new DbusThumbnailer ();

            finished.connect (() => { clear_unused_cache_files.begin (); });
        }

        public void begin_scan () {
            detect_video_files.begin (Audience.settings.library_folder);
        }

        public async void detect_video_files (string source) throws GLib.Error {
            File directory = File.new_for_path (source);

            FileMonitor monitor = directory.monitor (FileMonitorFlags.NONE, null);
            monitor.changed.connect ((src, dest, event) => {
                if (event == GLib.FileMonitorEvent.DELETED) {
                    video_file_deleted (src.get_path ());
                }
                else if (event == GLib.FileMonitorEvent.CHANGES_DONE_HINT) {
                    FileInfo file_info;
                    try {
                        file_info = src.query_info (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN + "," + FileAttribute.STANDARD_TYPE, 0);
                    } catch (Error e) {
                        warning (e.message);
                        return;
                    }
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        detect_video_files.begin (src.get_path ());
                    } else if (is_file_valid (file_info)) {
                        string src_path = src.get_path ();
                        crate_video_object (file_info, Path.get_dirname (src_path), Path.get_basename (src_path));
                    }
                }
            });
            monitoring_directories.add (monitor);

            var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE + "," + FileAttribute.STANDARD_IS_HIDDEN, 0);

            if (children != null) {
                FileInfo file_info;
                while ((file_info = children.next_file ()) != null) {
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        detect_video_files.begin (source + "/" + file_info.get_name ());
                        continue;
                    }

                    if (is_file_valid (file_info)) {
                        crate_video_object (file_info, source);
                    }
                }
            }
            if (directory.get_path () == Audience.settings.library_folder) {
                finished ();
            }
        }

        private bool is_file_valid (FileInfo file_info) {
            string mime_type = file_info.get_content_type ();
            return !file_info.get_is_hidden () && mime_type.length >= 5 && mime_type.substring (0, 5) == "video";
        }

        private void crate_video_object (FileInfo file_info, string source, string name = "") {
            if (name == "") {
                name = file_info.get_name ();
            }
            var video = new Audience.Objects.Video (source, name, file_info.get_content_type ());
            video_file_detected (video);
            poster_hash.add (video.hash + ".jpg");
            has_items = true;
        }

        public string? get_thumbnail_path (File file) {
            if (!file.is_native ()) {
                return null;
            }
            string? path = null;
            try {
                var info = file.query_info (FileAttribute.THUMBNAIL_PATH + "," + FileAttribute.THUMBNAILING_FAILED, FileQueryInfoFlags.NONE);
                path = info.get_attribute_as_string (FileAttribute.THUMBNAIL_PATH);
                var failed = info.get_attribute_boolean (FileAttribute.THUMBNAILING_FAILED);

                if (failed || path == null) {
                    return null;
                }

                path = path.replace ("normal", "large");

                File large_thumbnail = File.new_for_path (path);
                if (!large_thumbnail.query_exists ()) {
                    return null;
                }
            } catch (Error e) {
                warning (e.message);
                return null;
            }

            return path;
        }

        public void clear_cache (Audience.Objects.Video video) {
            File file = File.new_for_path (video.poster_cache_file);
            if (file.query_exists ()) {
                file.delete_async.begin (Priority.DEFAULT, null);
            }
        }

        public async void clear_unused_cache_files () {
            File directory = File.new_for_path (App.get_instance ().get_cache_directory ());
            try {
                var children = directory.enumerate_children (FileAttribute.STANDARD_NAME, 0);

                if (children != null) {
                    FileInfo file_info;
                    while ((file_info = children.next_file ()) != null) {
                        if (!poster_hash.contains (file_info.get_name ())) {
                            children.get_child (file_info).delete_async.begin ();
                        }
                    }
                }
            } catch (Error e) {
                warning (e.message);
            }
        }
    }
}
