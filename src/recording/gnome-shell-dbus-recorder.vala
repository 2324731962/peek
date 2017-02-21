/*
Peek Copyright (c) 2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Gnome.Shell;
using Peek.PostProcessing;

namespace Peek.Recording {

  public class GnomeShellDbusRecorder : BaseScreenRecorder {
    private Screencast screencast;

    private const string DBUS_NAME = "org.gnome.Shell.Screencast";

    public GnomeShellDbusRecorder () throws IOError {
      screencast = Bus.get_proxy_sync (
        BusType.SESSION,
        DBUS_NAME,
        "/org/gnome/Shell/Screencast");
    }

    public override bool record (RecordingArea area) {
      // Cancel running recording
      cancel ();

      bool success = false;

      var options = new HashTable<string, Variant> (null, null);
      options.insert ("framerate", new Variant.int32 (framerate));
      options.insert ("pipeline", build_gst_pipeline (area));

      if (!capture_mouse) {
        options.insert ("draw-cursor", false);
      }

      try {
        string file_template = Path.build_filename (
          Environment.get_tmp_dir (), "peek%d" + get_temp_file_extension ());
        debug (file_template);
        screencast.screencast_area (
          area.left, area.top, area.width, area.height,
          file_template, options, out success, out temp_file);
        stdout.printf ("Recording to file %s\n", temp_file);
      } catch (DBusError e) {
        stderr.printf ("Error: %s\n", e.message);
        return false;
      } catch (IOError e) {
        stderr.printf ("Error: %s\n", e.message);
        return false;
      }

      is_recording = success;
      return success;
    }

    public static bool is_available () throws PeekError {
      // In theory the dbus service can be installed, but it will only work
      // if Gnome Shell is running.
      if (!DesktopIntegration.is_gnome ()) {
        return false;
      }

      try {
        Freedesktop.DBus dbus = Bus.get_proxy_sync (
          BusType.SESSION,
          "org.freedesktop.DBus",
          "/org/freedesktop/DBus");
        return dbus.name_has_owner (DBUS_NAME);
      } catch (DBusError e) {
        stderr.printf ("Error: %s\n", e.message);
        throw new PeekError.SCREEN_RECORDER_ERROR (e.message);
      } catch (IOError e) {
        stderr.printf ("Error: %s\n", e.message);
        throw new PeekError.SCREEN_RECORDER_ERROR (e.message);
      }
    }

    protected override void stop_recording () {
      try {
        screencast.stop_screencast ();
        finalize_recording ();
      } catch (DBusError e) {
        stderr.printf ("Error: %s\n", e.message);
        recording_aborted (0);
      } catch (IOError e) {
        stderr.printf ("Error: %s\n", e.message);
        recording_aborted (0);
      }
    }

    private string build_gst_pipeline (RecordingArea area) {

      // Default pipeline is for Gnome Shell up to 2.22:
      // "vp8enc min_quantizer=13 max_quantizer=13 cpu-used=5 deadline=1000000 threads=%T ! queue ! webmmux"
      // Gnome Shell 3.24 will use vp9enc with same settings.
      var pipeline = new StringBuilder ();

      if (downsample > 1) {
        int width = area.width / downsample;
        int height = area.height / downsample;
        pipeline.append_printf ("videoscale ! video/x-raw,width=%i,height=%i ! ", width, height);
      }

      if (output_format == OUTPUT_FORMAT_GIF) {
        pipeline.append ("x264enc speed-preset=ultrafast threads=%T ! ");
        pipeline.append ("queue ! avimux");
      } else {
        pipeline.append ("vp8enc min_quantizer=13 max_quantizer=13 cpu-used=5 deadline=1000000 threads=%T ! ");
        pipeline.append ("queue ! webmmux");
      }

      debug ("Using GStreamer pipeline %s", pipeline.str);
      return pipeline.str;
    }

    private string get_temp_file_extension () {
      return output_format == OUTPUT_FORMAT_GIF ? ".avi" : ".webm";
    }
  }

}
