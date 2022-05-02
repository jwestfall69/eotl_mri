# eotl_mri - Medic Rage Info
This is a TF2 sourcemod plugin

When healing a soldier that has Buff Banner, Battalion's Backup, or Concheror equiped, it will display the soldier's rage percentage on the medic's HUD.

![example pic](eotl_mri_example.png)<p>

By default mri is disabled for each user.

### Say Commands
<hr>

**!mri** - enables mri for the user

**!mri disable** - disables mri for the user

### ConVars
<hr>

**eotl_mri_display_interval [seconds]**

How often to display update mri info on the medics HUD

Default: 0.5

**eotl_mri_display_x [float]**

The X location as a percentage from 0.0 to 1.0 of where the rage info should be printed on the medics screen.  0.0 is the left side of the screen, 1.0 is the right side.

Be aware this value is the start location of the text.

Default: 0.01

**eotl_mri_display_y [float]**

The Y location as a percentage from 0.0 to 1.0 of where the rage info should be printed on the medics screen.  0.0 is the top of the screen, 1.0 is the bottom.

Default: 0.5

The above default x/y values put the text in the middle left of the screen.

**eotl_mri_debug [0/1]**

Disable/Enable debug logging

Default: 0 (disabled)