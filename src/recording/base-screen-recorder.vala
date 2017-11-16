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

    public bool is_recording { get; protected set; }

    public RecordingConfig config { get; protected set; }

    private PostProcessor? active_post_processor = null;

    private bool _is_cancelling;
    protected bool is_cancelling {
      get {
        return _is_cancelling && !is_recording;
      }
    }

    public BaseScreenRecorder () {
      config = new RecordingConfig();
    }

    public abstract bool record (RecordingArea area);

    public void stop () {
      debug ("Recording stopped");
      _is_cancelling = false;
      is_recording = false;
      stop_recording ();
    }

    protected void finalize_recording () {
      debug ("Started post processing");
      var pipeline = build_post_processor_pipeline ();
      run_post_processors_async.begin (pipeline, (obj, res) => {
        var file = run_post_processors_async.end (res);
        debug ("Finished post processing");

        if (file != null) {
          FileUtils.chmod (file.get_path (), 0644);
          recording_finished (file);
        } else {
          recording_aborted (0);
        }
      });
      recording_postprocess_started ();
    }

    public void cancel () {
      if (is_recording) {
        _is_cancelling = true;
        is_recording = false;
        stop_recording ();
        remove_temp_file ();
        recording_aborted (0);
      } else if (active_post_processor != null) {
        active_post_processor.cancel ();
        active_post_processor = null;
        recording_aborted (0);
      }
    }

    protected abstract void stop_recording ();

    protected virtual PostProcessingPipeline build_post_processor_pipeline () {
      var pipeline = new PostProcessingPipeline ();

      if (config.output_format == OUTPUT_FORMAT_GIF) {
        if (config.gifski_enabled && GifskiPostProcessor.is_available ()) {
          pipeline.add (new ExtractFramesPostProcessor ());
          pipeline.add (new GifskiPostProcessor (config));
        } else if (FfmpegPostProcessor.is_available ()) {
          pipeline.add (new FfmpegPostProcessor (config));
        } else if (ImagemagickPostProcessor.is_available ()) {
          pipeline.add (new ExtractFramesPostProcessor ());
          pipeline.add (new ImagemagickPostProcessor (config));
        }
      } else if (config.output_format == OUTPUT_FORMAT_APNG) {
        pipeline.add (new FfmpegPostProcessor (config));
      }

      return pipeline;
    }

    private async File? run_post_processors_async (PostProcessingPipeline pipeline) {
      var files = new Array<File> ();
      files.append_val (File.new_for_path (temp_file));

      active_post_processor = pipeline;
      files = yield pipeline.process_async (files);
      active_post_processor = null;
      temp_file = null;

      if (files == null || files.length == 0) {
        return null;
      }

      return files.index (0);
    }

    protected void remove_temp_file () {
      if (temp_file != null) {
        FileUtils.remove (temp_file);
        temp_file = null;
      }
    }
  }

}
