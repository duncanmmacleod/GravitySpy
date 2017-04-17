#!/usr/bin/python

# Copyright (C) 2017 Michael Coughlin
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 3 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

import os, sys
import subprocess
import numpy as np
import optparse
from sqlalchemy.engine import create_engine
import pandas as pd
import pdb

__author__ = "Michael Coughlin <michael.coughlin@ligo.org>"
__version__ = 1.0
__date__    = "4/17/2017"

# =============================================================================
#
#                               DEFINITIONS
#
# =============================================================================

def parse_commandline():
    """@parse the options given on the command-line.
    """
    parser = optparse.OptionParser(usage=__doc__,version=__version__)

    parser.add_option("-b", "--database", help="Database (O1GlitchClassification,classification,glitches).", default="glitches")
    parser.add_option("-o", "--outdir", help="Output directory.",default ="./TrainingSet")

    parser.add_option("-v", "--verbose", action="store_true", default=False,
                      help="Run verbosely. (Default: False)")

    opts, args = parser.parse_args()

    # show parameters
    if opts.verbose:
        print >> sys.stderr, ""
        print >> sys.stderr, "running network_eqmon..."
        print >> sys.stderr, "version: %s"%__version__
        print >> sys.stderr, ""
        print >> sys.stderr, "***************** PARAMETERS ********************"
        for o in opts.__dict__.items():
          print >> sys.stderr, o[0]+":"
          print >> sys.stderr, o[1]
        print >> sys.stderr, ""

    return opts

# Parse command line
opts = parse_commandline()

TrainingFolder = opts.outdir
if not os.path.isdir(TrainingFolder):
    os.mkdir(TrainingFolder) 
database = opts.database

engine = create_engine('postgresql://{0}:{1}@gravityspy.ciera.northwestern.edu:5432/gravityspy'.format(os.environ['QUEST_SQL_USER'],os.environ['QUEST_SQL_PASSWORD']))
tmp = pd.read_sql(database,engine)

tmp = tmp.loc[~(tmp.Filename1 == None) & (tmp.ImageStatus == 'Training')]

for label in tmp.Label.unique():
    ThisTrainingFolder = os.path.join(TrainingFolder,label)
    if not os.path.isdir(ThisTrainingFolder):
        os.mkdir(ThisTrainingFolder)
    os.chdir(ThisTrainingFolder)
    tmp2 = tmp.loc[tmp.Label == label]
    for ifo in tmp2.ifo.unique():
        if ifo == "H1":
            hostpath = "ldas-pcdev2.ligo-wa.caltech.edu"
            userpath = "/home/scott.coughlin/"
        elif ifo == "L1":
            hostpath = "ldas-pcdev2.ligo-la.caltech.edu"
            userpath = "/home/scoughlin"

        pd.DataFrame(tmp2.loc[(tmp.ifo == ifo),['Filename1','Filename2','Filename3','Filename4']].as_matrix().flatten()).to_csv(open('filenames.txt','w'),index=False,header=False)
        os.system("gsiscp filenames.txt {0}:{1}".format(hostpath,userpath))
        os.system("gsissh {0} 'tar -cz --file={1}_{2}.tar.gz --files-from=filenames.txt'".format(hostpath,ifo,label))
        os.system("gsiscp {0}:{1}/{2}_{3}.tar.gz .".format(hostpath,userpath,ifo,label))
        os.system("tar -xzf {0}_{1}.tar.gz".format(ifo,label))
    os.system("find home/ -name '*.png' -exec mv {} . \;")
    
