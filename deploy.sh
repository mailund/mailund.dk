#!/bin/sh

hugo && rsync -a public/ mailund@mailund.dk:htdocs/
