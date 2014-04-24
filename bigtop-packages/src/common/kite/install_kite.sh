#!/bin/sh

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

usage() {
  echo "
usage: $0 <options>
  Required not-so-options:
     --build-dir=DIR             path to dist.dir
     --prefix=PREFIX             path to install into

  Optional options:
     --lib-dir=DIR               path to install home [/usr/lib/kite]
     --build-dir=DIR             path to dist dir
     ... [ see source for more similar options ]
  "
  exit 1
}

OPTS=$(getopt \
  -n $0 \
  -o '' \
  -l 'prefix:' \
  -l 'lib-dir:' \
  -l 'build-dir:' -- "$@")

if [ $? != 0 ] ; then
    usage
fi

eval set -- "$OPTS"
while true ; do
    case "$1" in
        --prefix)
        PREFIX=$2 ; shift 2
        ;;
        --build-dir)
        BUILD_DIR=$2 ; shift 2
        ;;
        --lib-dir)
        LIB_DIR=$2 ; shift 2
        ;;
        --)
        shift ; break
        ;;
        *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
done

for var in PREFIX BUILD_DIR ; do
  if [ -z "$(eval "echo \$$var")" ]; then
    echo Missing param: $var
    usage
  fi
done

LIB_DIR=${LIB_DIR:-/usr/lib/kite}

# First we'll move everything into lib
install -d -m 0755 $PREFIX/$LIB_DIR
cp -r $BUILD_DIR/* $PREFIX/$LIB_DIR

# Cloudera specific
install -d -m 0755 $PREFIX/$LIB_DIR/cloudera
cp cloudera/cdh_version.properties $PREFIX/$LIB_DIR/cloudera/

# Replace every Avro or Parquet jar with a symlink to the versionless symlinks in our distribution
# This regex matches upstream versions, plus CDH versions, betas and snapshots if they are present
versions='s#-[0-9].[0-9].[0-9]\(-cdh[0-9\-\.]*[0-9]\)\?\(-beta-[0-9]\+\)\?\(-SNAPSHOT\)\?##'
timestamps='s#-[0-9]\{8\}\.[0-9]\{6\}-[0-9]\+##'
for dir in $PREFIX/${LIB_DIR}/lib; do
    for old_jar in `find $dir -maxdepth 1 -name avro*.jar -o -name parquet*.jar | grep -v 'cassandra'`; do
        base_jar=`basename $old_jar`; new_jar=`echo $base_jar | sed -e $versions | sed -e $timestamps`
        rm $old_jar && ln -fs /usr/lib/${base_jar/[-.]*/}/$new_jar $dir/
    done
done
