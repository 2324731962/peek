/*
Peek Copyright (c) 2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Peek.PostProcessing;

namespace Peek.Recording {

  public abstract class BaseScreenRecorder : Object, ScreenRecorder {
    protected string temp_file;

    public bool is_recording { get; protected set; default = false; }

    public string output_format { get; set; default = OUTPUT_FORMAT_GIF; }

    public int framerate { get; set; default = DEFAULT_FRAMERATE; }

    public int downsample { get; set; default = DEFAULT_DOWNSAMPLE; }

    public bool capture_mouse { get; set; default = true; }

    public abstract bool record (RecordingArea area);

    public void stop () {
      debug ("Recording stopped");
      is_recording = false;
      stop_recording ();
    }

    protected void finalize_recording () {
      debug ("Started post processing");
      run_post_processors_async.begin ((obj, res) => {
        var file = run_post_processors_async.end (res);
        debug ("Finished post processing");
        recording_finished (file);
      });
      recording_postprocess_started ();
    }

    public void cancel () {
      if (is_recording) {
        stop_recording ();
        is_recording = false;
        remove_temp_file ();
        recording_aborted (0);
      }
    }

    protected abstract void stop_recording ();

    private async File? run_post_processors_async () {
      var file = File.new_for_path (temp_file);

      if (output_format == OUTPUT_FORMAT_GIF) {
        var postProcessor = new ImagemagickPostProcessor (framerate);
        file = yield postProcessor.process_async (file);
        remove_temp_file ();
      }

      temp_file = null;

      return file;
    }

    private void remove_temp_file () {
      if (temp_file != null) {
        FileUtils.remove (temp_file);
        temp_file = null;
      }
    }
  }

}
