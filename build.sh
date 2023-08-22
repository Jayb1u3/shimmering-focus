#!/usr/bin/env zsh
#───────────────────────────────────────────────────────────────────────────────

# WHAT THIS SCRIPT DOES
# - Check the yaml from the Style Settings for errors. If there are any, the
#	 build is aborted, the errors are passed (e.g. for a notification) and the
#	 Style Settings tab is opened.
# - takes argument as commit message (uses "chore" if executed without argument)
# - bumps version number in css file
# - CSS is linted and minified
# - The docs are linted and checked for invalid links
# - ToC in the CSS file is updated
# - updates download counts in badges of the .md files
# - adds a copy the non-minified css file for documentation
# - updates the stylelint-file
# - git add, commit, pull, and push to the remote repo

#───────────────────────────────────────────────────────────────────────────────

# Goto git root
cd "$(dirname "$0")" || exit 1
# shellcheck disable=2164
r=$(git rev-parse --git-dir) && r=$(cd "$r" && pwd)/ && cd "${r%%/.git/*}"

# CONFIG
CSS_PATH="./source.css"

#───────────────────────────────────────────────────────────────────────────────

# DEPENDENCIES
npm_location="$(npm root)/.bin/"
export PATH=/usr/local/lib:/usr/local/bin:/opt/homebrew/bin/:$npm_location:$PATH

if ! command -v yamllint &> /dev/null; then echo "yamllint not installed." ; return 1 ; fi
if ! command -v stylelint &> /dev/null; then echo "stylelint not installed." ; return 1 ; fi
if ! command -v prettier &> /dev/null; then echo "prettier not installed." ; return 1 ; fi
if ! command -v git &> /dev/null; then echo "git not installed." ; return 1 ; fi
if ! command -v lightningcss &> /dev/null; then echo "lightningcss (\`npm i\`) not installed." ; return 1 ; fi

#───────────────────────────────────────────────────────────────────────────────

# YAMLLINT TEST
# - Abort build if yaml invalid
# - requires style settings placed at the very bottom of the theme css
YAMLLINT_OUTPUT=$(
	sed -n '/@settings/,$p' "$CSS_PATH" |
	sed '1,2d;$d'|
	sed '$d' |
	yamllint - --config-data="{extends: relaxed, rules: {trailing-spaces: disable}}"
)

if [[ $? == 1 ]]; then
	echo "YAML ERROR"
	echo "$YAMLLINT_OUTPUT" | tail -n+2
	# open Style Settings if Advanced URI plugin installed
	open "obsidian://advanced-uri?settingid=obsidian-style-settings"
	exit 1
fi

# Autofixing & Linting
stylelint --fix "$CSS_PATH" &>/dev/null
prettier --write "$CSS_PATH" &>/dev/null

#───────────────────────────────────────────────────────────────────────────────

# Update ToC
printf "/* @TOC-SPLIT-MARKER */\n/*\n" > new_toc.css
grep -E "<+ " "$CSS_PATH" | sed -e "s/ \*\///" \
	-e "s/\/\* //" \
	-e "s/<<<<< /\t\t\t\t- /" \
	-e "s/<<<< /\t\t\t- /" \
	-e "s/<<< /\t\t- /" \
	-e "s/<< /\t- /" \
	-e "s/< /- /" \
	| tr -d "#" \
	| tail -n +2 \
	>> new_toc.css
split -p "@TOC-SPLIT-MARKER" "$CSS_PATH" temp
mv tempaa before_toc.css
mv tempac after_toc.css
cat before_toc.css new_toc.css after_toc.css > "$CSS_PATH"
rm new_toc.css before_toc.css tempab after_toc.css

# Bump version number
versionLine=$(grep -Ewn "^Version" "$CSS_PATH" | cut -d: -f1 | head -n1)
currentVersion=$(sed -n "${versionLine}p" "$CSS_PATH" | cut -d. -f2)
nextVersion=$((currentVersion + 1))
sed -E -i '' "${versionLine}s/(.*\.)[[:digit:]]+/\1$nextVersion/" "$CSS_PATH"
sed -E -i '' "s/(\"version\": \".*\.).*/\1$nextVersion\",/" "manifest.json"
SECOND_MANIFEST="$(dirname "$CSS_PATH")/manifest.json"
sed -E -i '' "s/(\"version\": \".*\.).*/\1$nextVersion\",/" "$SECOND_MANIFEST"

# Minify
split -p "@MINIFY-SPLIT-MARKER" "$CSS_PATH" temp # split off to prevent style settings from getting minified
mv tempaa info.css
mv tempab unminified_css_code.css
grep -vE "^# << " tempac > style_settings.css # remove yaml-navigation markers
rm tempac
lightningcss unminified_css_code.css --minify --output-file=minified_css_code.css
cat info.css minified_css_code.css style_settings.css > theme.css
rm info.css unminified_css_code.css minified_css_code.css style_settings.css

#───────────────────────────────────────────────────────────────────────────────

# get commit message
COMMIT_MSG="$*"
[[ -z "$COMMIT_MSG" ]] && COMMIT_MSG="patch"

# Copy for documentation purposes
cp "$DOTFILE_FOLDER/_linter-configs/stylelintrc.yml" ./.stylelintrc.yml

# Update Theme Download numbers in README.md
dl=$(curl -s "https://releases.obsidian.md/stats/theme" | grep -oe '"Shimmering Focus","download":[[:digit:]]*' | cut -d: -f2)
sed -E -i '' "s/badge.*-[[:digit:]]+-/badge\/downloads-$dl-/" ./README.md

#───────────────────────────────────────────────────────────────────────────────

# add to git
git add -A
git commit -m "$COMMIT_MSG"
git pull
echo -n | git push  # pass for notification

#───────────────────────────────────────────────────────────────────────────────
# INFO specific to my setup: copy theme file for fallback
cp "$CSS_PATH" "$VAULT_PATH/.obsidian/themes/Shimmering Focus/fallback.css"
