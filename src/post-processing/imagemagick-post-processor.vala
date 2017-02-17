/*
Peek Copyright (c) 2016-2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

namespace Peek.PostProcessing {

  public class ImagemagickPostProcessor : Object, PostProcessor {
    public int framerate { get; set; default = 15; }

    public ImagemagickPostProcessor (int framerate) {
      this.framerate = framerate;
    }

    public async File? process_async (File file) {
      try {
        SourceFunc callback = process_async.callback;

        double delay = (100.0 / framerate);
        var output_file = Utils.create_temp_file ("gif");
        string[] argv = {
          "convert",
          "-set", "delay", delay.to_string (),
          "-layers", "Optimize",
          file.get_path (),
          output_file
        };

        Pid pid;
        Process.spawn_async (null, argv, null,
          SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, out pid);

        ChildWatch.add (pid, (pid, status) => {
          // Triggered when the child indicated by pid exits
          Process.close_pid (pid);
          Idle.add ((owned) callback);
        });

        yield;
        return File.new_for_path (output_file);
      } catch (SpawnError e) {
        stderr.printf ("Error: %s\n", e.message);
        return null;
      } catch (FileError e) {
        stderr.printf ("Error: %s\n", e.message);
        return null;
      }
    }
  }

}
