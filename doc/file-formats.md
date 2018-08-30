# Graphics file formats

This file contains descriptions of various C64 graphics file formats which hold
multicolor bitmap images.


## Standard multicolor bitmap

These file formats store the full information on multicolor images: a bitmap,
videoram, coloram and a background color.




### Koala Painter 2

Multi color bitmap image with videoram, coloram and background color, the
de-facto standard on C64 for bitmap images. This is also the way BDP6 images
are stored in memory during editing.

Load: $6000-$8710, Size: $2711

| address       | offset   | size    | description      |
| ------------- | -------- | ------- | ---------------- |
| `$6000-$7f3f` | `$0000`  | `$1f40` | bitmap           |
| `$7f40-$8327` | `$1f40`  | `$03e8` | videoram         |
| `$8328-$870f` | `$2328`  | `$03e8` | colorram         |
| `$8710`       | `$2710`  | `$0001` | background color |



## Non-standard file formats

These format miss some information such as colorram data.


### Paint Magic


Multi color bitmap image with a *single byte* for the colorram.

Load: $3f8e-$63ff, Size: $2872

| address       | offset   | size    | description      |
| ------------- | -------- | ------- | ---------------- |
| `$3f8e-$3fff` | `$0000`  | `$0072` | display routine  |
| `$4000-$5f3f` | `$0072`  | `$1f40` | bitmap           |
| `$5f40`       | `$1fb2`  | `$0001` | background color |
| `$5f43`       | `$1fb5`  | `$0001` | colorram value   |
| `$5f44`       | `$1fb6`  | `$0001` | border color     |
| `$6000-$63e7` | `$2072`  | `$03e8` | videoram         |


