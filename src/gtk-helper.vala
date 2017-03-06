/*
Peek Copyright (c) 2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Gtk;

namespace Peek {

  public class GtkHelper {
    public static void hide_button_label (Button button) {
      var label = GtkHelper.find_first_child_of_type (button, typeof (Label));
      label.hide ();
    }

    public static void show_button_label (Button button) {
      var label = GtkHelper.find_first_child_of_type (button, typeof (Label));
      label.show ();
    }

    public static Widget? find_first_child_of_type (Container container, Type type) {
      var children = container.get_children ();

      foreach (var child in children) {
        var child_type = child.get_type ();
        if (child_type.is_a (type)) {
          return child;
        }
        else if (child_type.is_a (typeof (Container))) {
          return find_first_child_of_type ((Container) child, type);
        }
      }

      return null;
    }
  }
}
