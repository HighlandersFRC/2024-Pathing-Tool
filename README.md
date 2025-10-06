# Polar Pathing
Polar Pathing is an all-in-one FRC Autonomous tool with the following features:
- Quintic Hermite Spline Generation for Paths
- Trapezoidal Motion Profiles for Paths
- Organization of Multiple Paths in one Autonomous
- Robot Command Scheduling
- Branching (Conditional) Paths During Autonomous
- Configurable Robot Profiles to store Command, Condition, Robot Dimensions, and Robot Kinematic Information
- Configurable Field Images

## Installation
1. Start by downloading the latest release of Polar Pathing from the [releases](https://github.com/HighlandersFRC/2024-Pathing-Tool/releases)
2. Unzip the folder
3. Run pathing_tool.exe (Windows might stop you, so just click "More info" and then "Run anyway")
4. Link the app to an FRC repository, open the menu and then click on the settings. Then click "Connect to Repository" and select the path to your FRC Robot Code.

## Using the App

There are 2 main pages in the tool:

- Autonomous Page
- Path Page

To start, click "Create New Auto" on the home page. This will move you to the autonomous page.

1. Name your auto "Hello World" by using the text box at the top of the tool.
2. Click "Add Path" on the right side of the tool.
3. Name the path "A"
4. After adding the path, click on the dropdown on the right.
5. Click the pencil icon

This will move you to the path page. Here is where the core of your autos will be designed.

1. Click 5 points onto the game field image
2. Go to the edit tab on the bottom of the page
3. Click and drag the handles around the points to edit the path
4. Click the dropdown on the right to make fine adjustments to the points
5. Click on the "Smoothen" arrow to the right of the play button at the top of the screen
6. Click the play button on the top of the screen

These features can be used to edit the spline trajectories you want the robot to follow.

Next, we will add commands to our path.

1. Click on the third "Commands" tab on the bottom of the path page
2. Click into the settings and ensure your robot config has a few commands added
3. Click add command on the right
4. Choose "Add Command"
5. Click on the new command dropdown
6. Set the end time to 4s
7. Set the start time to 1s
8. Select a command of your choice
9. Press the play button at the top

This set of buttons can be used specify which commands need to be run at what times during the path.