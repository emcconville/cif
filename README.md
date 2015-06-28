# CIF

A command-line interface (CLI) for OS X's Core Image Filters.

Cif is a *small* utility that brings apple's built-in & embedded image
algorithms to a common API.


## Getting

For pre-built binaries, checkout
[https://github.com/emcconville/cif/releases/latest](https://github.com/emcconville/cif/releases/latest)

## Usage

Basic usage can be described as ...

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


## Included Batteries (also called Features)

### Filter Chaining

Multiple CIFilters can be executed in sequence. When `cif` reads additional
`-filter <filter>` arguments, it assumes the preceding filter's output should
be passed to the next filter as `-inputImage` parameter.

    cif -filter CIVibrance -inputImage input_image.jpg -inputAmount 50  \
        -filter CIBloom -outputImage out.png

Cif tries to be smart, so `-filter` & `-output` can be omitted.

    cif CIVibrance -inputImage input_image.jpg -inputAmount 50  \
        CIBloom out.png


### Color Functions

Common CSS color functions are supported.

    rgb(255, 0, 127)
    hsl(280, 50%, 100%)

Both `RGB`, and `HSL` colorspaces accept optional alpha channels between
0.0 & 1.0.

    rgba(255, 0, 127, 0.75)
    hsla(280, 50%, 100%, 0.75)


### X11 Color Names

Standard [X11 colors](https://en.wikipedia.org/wiki/X11_color_names) are
included. Input arguments will accept values like: `-inputColor Cyan`

### Pipes!

Core Image data can be read, our redirected to standard in & out; respectively.
This allows you to leverage `cif` along side existing UNIX applications.

    # Read from STDIN
    dot graphiviz.dot -Tpng | cif CIBloom -inputImage - -inputIntensity 4 \
                                          -outputImage ghostviz.png
    # Write to STDOUT
    cif CIBloom -inputImage something.png STDOUT | identify png:-


### Patterns

ImageMagick's inventory of tile patterns have been included. Any image input
arguments can leverage these patterns by prefixing a pattern name with
`pattern:` string. Example `-inputImage pattern:bricks`.

> *Note:* Patterns are unbound (infinite) in nature, so an additional
> `-size WIDTHxHEIGHT` will be required.

### Tab Completion

The bash script [CifGetOpt.sh](CifGetOpt.sh) should be sourced, or contents
copied to your `.bashrc`, or `.bash_profile` file. Tab behavior as follows:

    cif CIBl[TAB]
    # Will list available matching filters
    cif CIBloom -input[TAB]
    # Will list available input parameters

Note: Mileage will very based on environment configuration.


# Building

To build from source

    git clone https://github.com/emcconville/cif.git && cd cif
    xcodebuild -scheme cif -configuration 'Release' \
               CONFIGURATION_BUILD_DIR=/tmp/  build
    sudo cp -p /tmp/cif /usr/local/bin/cif
