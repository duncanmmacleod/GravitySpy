rsync -avz -e ssh --chmod=g-s --include="*/" --include="**/*.tar" --include="**/*.txt" --include="**/*.csv" --exclude="**/*.png" /home/michael.zevin/public_html/GravitySpy/ sbc538@quest.it.northwestern.edu:/xvaultevfs1/b1011/GravitySpy/H1/
