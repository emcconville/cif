# CIF

A command-line interface (CLI) for OS X's Core Image Filters.

## Getting & Building

To build from source

    git clone https://github.com/emcconville/cif.git && cd cif
    xcodebuild -scheme cif -configuration 'Release' \
               CONFIGURATION_BUILD_DIR=/tmp/  build
    sudo cp -p /tmp/cif /usr/local/bin/cif

For pre-built binaries, check https://github.com/emcconville/cif/releases

## Usage

Basic usage can be described s ...

    cif <filter> [arguments, ...] <output>

Where `<filter>` is a CoreImage Filter name, `[arguments, ...]` is one -or-
many input flags, and `<output>` refers to the finial output destination.

A common task of creating a Gaussian Blur

    cif CIGaussianBlur -inputImage input.png -inputRadius 4 output.png

To list all available Core Image Filters, the following will display all
supported filters.

    cif list

To read the description of each filter, and the related argument list, simply
run the list command followed by the filter name.

    cif list CIGaussianBlur


## Included Batteries 

### X11 Color Names

Standard [X11 colors](https://en.wikipedia.org/wiki/X11_color_names) are
included. Input arguments will accept values like: `-inputColor Cyan`


### Patterns

ImageMagick's inventory of tile patterns have been included. Any image input
arguments can leverage these patterns by prefixing a pattern name with `patern:`
string. Example `-inputImage pattern:bricks`.

> *Note:* Patterns are unbound (infinite) in nature, so an additional
> `-size WIDTHxHEIGHT` will be required.

### Tab Completion

The bash script [CifGetOpt.sh](CifGetOpt.sh) should be sourced, or contents
copied to your `.bashrc`, or `.bash_profile` file. Tab behavior as follows:

    cif CIBl[TAB]
    # Will list available matching filters
    cif CIBlool -input[TAB]
    # Will list available input paramaters

Note: Mileage will very based on environment configuration.
