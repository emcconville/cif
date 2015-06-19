# CIF

A command-line interface (CLI) for OS X's Core Image Filters.

## Getting & Building

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


## Help
