/*
Peek Copyright (c) 2015-2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Peek.PostProcessing;

namespace Peek.Recording {

  public abstract class CommandLineScreenRecorder : BaseScreenRecorder {
    protected Pid pid;
    protected IOChannel input;

    protected bool spawn_record_command (string[] args) {
      try {
        int standard_input;
        Process.spawn_async_with_pipes (null, args, null,
          SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
          null, out pid, out standard_input);

        input = new IOChannel.unix_new (standard_input);

        ChildWatch.add (pid, (pid, status) => {
          // Triggered when the child indicated by pid exits
          debug ("Recorder process closed");
          Process.close_pid (pid);

          if (!is_exit_status_success (status)) {
            recording_aborted (Process.exit_status (status));
          } else {
            finalize_recording ();
          }
        });

        is_recording = true;
        recording_started ();
        return true;
      } catch (SpawnError e) {
        stderr.printf ("Error: %s\n", e.message);
        return false;
      }
    }

    protected virtual bool is_exit_status_success (int status) {
      return Utils.is_exit_status_success (status);
    }
  }

}
