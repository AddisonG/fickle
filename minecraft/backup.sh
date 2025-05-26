#!/bin/bash

tar -czvf backup-$(date +%F_%H-%M).tar.gz world world_nether world_the_end plugins server.properties
