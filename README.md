# YaST Status

This repository contains a script which generates a simple
YaST Dashboard page in HTML.

## Usage

Just run

    ./y2status -v -o index.html

to generate the `index.html` file with the Dashboard content.

You need to run this command regularly to generate the new content.
For testing you might use the [devel/auto-update](devel/auto-update)
script.

## Note

To get full content you need access to the internal SUSE network and
access to the build service projects.

## Serving the Page

The generated page needs to be server by a web server, or testing
purposes you can use a Ruby builtin server, see the [devel/http_server](
devel/http_server) helper script.
