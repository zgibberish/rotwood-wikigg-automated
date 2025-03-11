source rwtextool/venv/bin/activate

unzip data.zip "images/icons_keyboard*"
unzip data.zip "images/icons_mouse*"
unzip data.zip "images/icons_nxjoycon*"
unzip data.zip "images/icons_nxpro*"
unzip data.zip "images/icons_other*"
unzip data.zip "images/icons_ps4*"
unzip data.zip "images/icons_ps5*"
unzip data.zip "images/icons_touch*"
unzip data.zip "images/icons_xbox360*"
find images/*.tex | xargs -I {} python rwtextool/src/tex2img.py -A {}
find images/*.* | xargs rm # remove tex and atlas files
find images/*/* | xargs -I {} mv {} images/ # move all pngs out
find images/*/ -type d | xargs rm -r # remove remaining folders
(cd images; find * -type f | xargs -I {} mv {} controlicons_{}) # put prefix in file names

