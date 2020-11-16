# mpv-sub-select

This script allows you to configure advanced subtitle track selection based on the current audio track and the names and language of the subtitle tracks. The script will automatically disable itself when `sid` is not set to `auto`.


## Configuration

Configuration is done in the `sub-select.json` file, stored in the `~~/script-opts/` config directory.

### Syntax
The syntax and available options are as follows:

```
[
    {
        "alang": "jpn",
        "slang": "eng",
        "blacklist": [ "sign" ],
        "whitelist": [ "english", "song" ]
    }
]
```

`alang` and `slang` are the language codes of the audio and subtitle tracks, while `blacklist` and `whitelist` are optional filters that can be used to choose subtitle tracks based on their track names. The blacklist requires that all entries not be present in the track name, while the whitelist requires that just one be present.

### String Matching
All matching is done using the lua `string.find` function, so supports [patterns](http://lua-users.org/wiki/PatternsTutorial). For example `eng?` could be used instead of `eng` so that the DVD language code `en` is also matched.

### Preference

The script moves down the list track preferences until any valid pair of audio and subtitle tracks are found. Once this happens the script immediately sets the subtitle track and terminates. If none of the tracks match then trak selection is deferred to mpv.

### Special Strings
Setting `alang` to `*` will match with any audio track. Setting `slang` to `no` will disable subtitles for that audio language.

## Synchronous vs Asynchronous Track Selection
The script has two different ways it can select subtitles, controlled with the `preload` script-opt. The default is to load synchronously during the preload phase, which is before track selection; this allows the script to seamlessly change the subtitles to the desired track without any indication that the tracks were switched manually. This likely has better compatability with other options and scripts.

The downside of this method is that when `--aid` is set to auto the script needs to scan the track-list and predict what track mpv will select. This is not a perfect process given my unfamiliarity with the mpv track selection algorithm, therefore in some rare situations this could result in the wrong track being selected. There are three solutions to this problem:

### Use Asynchronous Mode (default no)
Disable the hook by setting `preload=no`. This is the simplest and most efficient solution, however it means that track switching messages will printed to the console and it may break other scripts that use subtitle information.

### Force Prediction (default no)
Force the predicted track to be correct by setting `aid` to the predicted value. This can be enabled with `force_prediction=yes`. This method is not recommended, because the script's prediction algorithm is much more primitive than what is used by mpv.

### Detect Incorrect Predictions (default yes)
Check the audio track when playback starts and compare with the latest prediction, if the prediction was wrong then the subtitle selection is run again. This can be disabled with `detect_incorrect_predictions=no`. This is the best of both worlds, since 95% of the time the subtitles will load seamlessly, and on the rare occasion that the file has weird track tagging the correct subtitles will be reloaded. However, this method does have the highest computational overhead, if anyone cares about that.


## Examples

The [sub_select.conf](/sub_select.conf) file contains all of the options for the script and their defaults. The [sub-select.json](/sub-select.json) file contains an example set of track matches.