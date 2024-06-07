# WHAT THIS SCRIPT DOES
# - Check the yaml from the Style Settings for errors. If there are any, the
#   build is aborted, the errors are passed
# - bumps version number in css file and manifest
# - updates download counts in badges of the README files
# - update changelog
# - git add, commit, pull, and push to the remote repo

#───────────────────────────────────────────────────────────────────────────────
# CONFIG
css_path="./theme.css"

#───────────────────────────────────────────────────────────────────────────────
# TEST: YAML VALIDATION

# Abort build if yaml invalid
# (requires style-settings placed at the very bottom of the theme's css)
sed -n '/@settings/,$p' "$css_path" | sed '1d;$d' | sed '$d' > style-settings-temp.yml
yamllint_output=$(npx yaml-validator style-settings-temp.yml)
if [[ $? == 1 ]]; then
	echo "YAML ERROR"
	echo "$yamllint_output" | sed '1d'
	return 1
fi
rm style-settings-temp.yml

#───────────────────────────────────────────────────────────────────────────────
# BUMP VERSION NUMBER

versionLine=$(grep --line-number --max-count=1 "^Version" "theme.css")
versionLnum=$(echo "$versionLine" | cut -d: -f1)

currentVer=$(echo "$versionLine" | cut -d. -f2)
nextVer=$((currentVer + 1))

manifest="$(dirname "$css_path")/manifest.json"
sed -E -i '' "${versionLnum} s/$currentVer/$nextVer/" "$css_path"
sed -E -i '' "/version/ s/$currentVer/$nextVer/" "$manifest"

# Update Theme Download numbers in README.md
dl=$(curl -s "https://releases.obsidian.md/stats/theme" |
	grep -oe '"Shimmering Focus","download":[[:digit:]]*' |
	cut -d: -f2)
sed -E -i '' "s/badge.*-[[:digit:]]+-/badge\/downloads-$dl-/" ./README.md

#───────────────────────────────────────────────────────────────────────────────
# CHANGELOG

# only add to changelog if on `main`
if [[ "$(git branch --show-current)" == "main" ]]; then
	commits_since_last_publish=$(git log :/publish.. --format="- %cs %s")

	echo "$commits_since_last_publish" |
		grep -vE "build|ci|style" |                                 # don'nt include internal changes
		sed -E "s/^(- [0-9-]+) ([^ ]+): /\1 **\2**: /" >> "temp.md" # bold title
	grep -v "^$" "Changelog.md" >> "temp.md"
	mv -f "temp.md" "Changelog.md"
fi

#───────────────────────────────────────────────────────────────────────────────
# GIT ADD, COMMIT, PULL, AND PUSH

# needs piping stderr to stdin, since git push reports an error even on success
git add --all && git commit -m "publish" --author="🤖 automated<auto@build.sh>"
git pull && git push 2>&1

#───────────────────────────────────────────────────────────────────────────────
# INFO specific to my setup

if [[ "$OSTYPE" =~ "darwin" ]]; then
	repo_dir=$(git rev-parse --show-toplevel)
	# switch back to symlink
	while read -r line; do
		repo_path=$(echo "$line" | cut -d, -f2 | sed "s|^~|$HOME|")
		theme_path="$repo_path/.obsidian/themes/Shimmering Focus"
		[[ -d "$theme_path" ]] || continue
		cd "$theme_path" || return 1

		cp "$css_path" "fallback.css"     # copy theme file for fallback
		ln -sf "fallback.css" "theme.css" # re-create symlink
	done < "$HOME/.config/perma-repos.csv"

	# confirmation sound
	afplay "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/siri/jbl_confirm.caf" & # codespell-ignore

	# delete this repo folder
	# HACK for whatever reason, the first run does not delete due to missing
	# permissions, even though all permissions are there and owner is also set
	# correctly…
	rm -rf "$repo_dir" &> /dev/null
	rm -rf "$repo_dir" &> /dev/null
fi
