# mpv-sub-select

This script allows you to configure advanced subtitle track selection based on the current audio track and the names and language of the subtitle tracks. The script will automatically disable itself when mpv is started with `--sid` not set to `auto`, or when `--track-auto-selection` is disabled.

## Configuration

Configuration is done in the `sub-select.json` file, stored in the `~~/script-opts/` config directory.

### Syntax

The syntax and available options are as follows:

```json
[
    {
        "alang": "jpn",
        "slang": "eng",
        "blacklist": [ "sign" ],
        "whitelist": [ "english", "song" ]
    }
]
```

`alang` and `slang` are the language codes of the audio and subtitle tracks, while `blacklist` and `whitelist` are optional filters that can be used to choose subtitle tracks based on their track names. The blacklist and whitelist will trigger if any of their entries are present in the track name.

`alang` and `slang` can also be arrays of valid codes to allow matching with multiple language codes.
If multiple `slang` languages are included, then the first code to match to a track will be the one used.

**Do not use uppercase characters for any options unless using [patterns](#string-matching).**

All titles are converted to lowercase automatically to allow more matches.

### String Matching

All matching is done using the lua `string.find` function, so supports [patterns](https://www.lua.org/manual/5.1/manual.html#5.4.1). For example `eng?` could be used instead of `eng` so that the DVD language code `en` is also matched.

**The characters `^$()%.[]*+-?` have special behaviour and muct be escaped with `%`.**

### Preference

The script moves down the list of track preferences until any valid pair of audio and subtitle tracks are found. Once this happens the script immediately sets the subtitle track and terminates. If none of the tracks match then track selection is deferred to mpv.

### Special Strings

There are a number of strings that can be used for the `alang` and `slang` which have special behaviour.

**alang:**
| String | Action                                  |
|--------|-----------------------------------------|
| *      | matches any language                    |
| no     | matches when no audio track is selected |

**slang:**
| String  | Action                                        |
|---------|-----------------------------------------------|
| *       | matches any language                          |
| no      | disables subs if `alang` matches              |
| default | enables subtitles with the `default` tag      |
| forced  | enables subtitles with the `forced` tag       |

## Commands

The script supports two commands to control subtitle selection.

### `script-message select-subtitles`

This command will force subtitle selection during runtime based on the current audio track.

### `script-message sub-select [arg]`

This command will enable/disable the script. Valid arguments are `enable`, `disable`, and `toggle`. If the script gets enabled then the current subtitle track will be reselected.

## Auto-Switch Mode

The `detect_audio_switches` script-opt allows one to enable Auto-Switch Mode. In this mode the script will automatically reselect the subtitles when the script detects that the audio language has changed.
This setting ignores `--sid=auto`, but when using synchronous mode the script will not change the original `sid` until the first audio switch. This feature still respects `--track-auto-selection`.
This mode can be disabled during runtime wi the `sub-select` script message shown above.


## Synchronous vs Asynchronous Track Selection

The script has two different ways it can select subtitles, controlled with the `preload` script-opt. The default is to load synchronously during the preload phase, which is before track selection; this allows the script to seamlessly change the subtitles to the desired track without any indication that the tracks were switched manually. This likely has better compatability with other options and scripts.

The downside of this method is that when `--aid` is set to auto the script needs to scan the track-list and predict what track mpv will select. Therefore, in some rare situations, this could result in the wrong audio track prediction, and hence the wrong subtitle being selected. There are three solutions to this problem:

### Use Asynchronous Mode (default no)

Disable the hook by setting `preload=no`. This is the simplest and most efficient solution, however it means that track switching messages will be printed to the console and it may break other scripts that use subtitle information.

### Force Prediction (default no)

Force the predicted track to be correct by setting `aid` to the predicted value. This can be enabled with `force_prediction=yes`.
This method works well, but is not ideal if one wants to utilise a more refined audio track selector, or if mpv's default is more desirable.

### Detect Incorrect Predictions (default yes)

Check the audio track when playback starts and compare with the latest prediction, if the prediction was wrong then the subtitle selection is run again. This can be disabled with `detect_incorrect_predictions=no`. This is the best of both worlds, since 99% of the time the subtitles will load seamlessly, and on the rare occasion that the file has weird track tagging the correct subtitles will be reloaded. However, this method does have the highest computational overhead, if anyone cares about that.

Auto-Select Mode enables this intrinsically.

## Examples

The [sub_select.conf](/sub_select.conf) file contains all of the options for the script and their defaults. The [sub-select.json](/sub-select.json) file contains an example set of track matches.
