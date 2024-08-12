#!/usr/bin/env bash
mkdir -p /tmp/data/storage /tmp/data/public
chmod 755 /tmp/data/public
chown -R 1500:1500 /tmp/data/php /tmp/data/public /tmp/data/storage
