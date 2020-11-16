# mpv-sub-select

This script allows you to configure advanced subtitle track selection based on the current audio track and the names and language of the subtitle tracks.


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


## Other Options
### Audio Select

### Active Switching

### Synchronous vs Asynchronous Track Selection

## Examples

The `sub_select.conf` file contains all of the options for the script and their defaults. The `sub-select.json` file contains an example set of track matches.