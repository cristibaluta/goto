# goto

A macOS cmd to open Terminal tabs and Finder windows to various locations on your computer. 

## Usage ideas:
    - add your projects and navigate to them faster
    - add locations to Xcode derived data and other impossible to remember locations
    

## Commands:
     list               List all paths
     set <name> [path]  Assign a name to the path. If path is missing use current directory
     delete <name>      Delete the path with name
     finder <name>      Open new Finder window at path
     terminal <name>    Open new Terminal tab at path
     <name>             Open new Terminal tab or file at path
     file <name>        Open file at path

## Install:
1. Get the build/goto and place it in usr/local/bin
2. Build the xcode project
