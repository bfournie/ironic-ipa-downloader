#!/bin/bash -xe
#CACHEURL=http://172.22.0.1/images

# Check and set http(s)_proxy. Required for cURL to use a proxy
export http_proxy=${http_proxy:-$HTTP_PROXY}
export https_proxy=${https_proxy:-$HTTPS_PROXY}
export no_proxy=${no_proxy:-$NO_PROXY}

# Which image should we use
SNAP=${1:-current-tripleo-rdo}
IPA_BASEURI=${IPA_BASEURI:-https://images.rdoproject.org/centos8/wallaby/rdo_trunk/$SNAP/}

FILENAME=ironic-python-agent
FILENAME_EXT=.tar
FFILENAME=$FILENAME$FILENAME_EXT

mkdir -p /shared/html/images /shared/tmp
cd /shared/html/images

# Is this a RHEL based image? If so the IPA image is already here, so
# we don't need to download it
if [[ -e /var/tmp/$FILENAME.initramfs && \
      -e /var/tmp/$FILENAME.kernel ]] ; then
    cp /var/tmp/$FILENAME.initramfs $FILENAME.initramfs
    cp /var/tmp/$FILENAME.kernel $FILENAME.kernel
    # In case of OKD, an IPA image from the current-tripleo-rdo repository is used,
    # which does not come with a manifest
    if [[ -e /var/tmp/$FILENAME.manifest ]] ; then
        cp /var/tmp/$FILENAME.manifest $FILENAME.manifest
    fi
    rm -f /var/tmp/$FILENAME.*
    exit 0
fi

TMPDIR=$(mktemp -d -p /shared/tmp)

# If we have a CACHEURL and nothing has yet been downloaded
# get header info from the cache
ls -l
if [ -n "$CACHEURL" -a ! -e $FFILENAME.headers ] ; then
    curl -v -g --fail -O "$CACHEURL/$FFILENAME.headers" || true
fi

# Download the most recent version of IPA
if [ -e $FFILENAME.headers ] ; then
    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\r")
    cd $TMPDIR
    curl -v -g --dump-header $FFILENAME.headers -O $IPA_BASEURI/$FFILENAME --header "If-None-Match: $ETAG" || cp /shared/html/images/$FFILENAME.headers .
    # curl didn't download anything because we have the ETag already
    # but we don't have it in the images directory
    # Its in the cache, go get it
    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\"\r")
    if [ ! -s $FFILENAME -a ! -e /shared/html/images/$FILENAME-$ETAG/$FFILENAME ] ; then
        mv /shared/html/images/$FFILENAME.headers .
        curl -v -g -O "$CACHEURL/$FILENAME-$ETAG/$FFILENAME"
    fi
else
    cd $TMPDIR
    curl -v -g --dump-header $FFILENAME.headers -O $IPA_BASEURI/$FFILENAME
fi

if [ -s $FFILENAME ] ; then
    tar -xf $FFILENAME

    ETAG=$(awk '/ETag:/ {print $2}' $FFILENAME.headers | tr -d "\"\r")
    cd -
    chmod 755 $TMPDIR
    mv $TMPDIR $FILENAME-$ETAG
    ln -sf $FILENAME-$ETAG/$FFILENAME.headers $FFILENAME.headers
    ln -sf $FILENAME-$ETAG/$FILENAME.initramfs $FILENAME.initramfs
    ln -sf $FILENAME-$ETAG/$FILENAME.kernel $FILENAME.kernel
else
    rm -rf $TMPDIR
fi
