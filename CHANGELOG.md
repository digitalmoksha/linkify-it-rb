1.1.1.0
-------

Synced with linkify-it 1.1.1, includes these changes:

* 1.1.1 / 2015-06-09
  - Allow ".." in link paths.

* 1.1.0 / 2015-04-21
  - Added options to control fuzzy links recognition (`fuzzyLink: true`,
  `fuzzyEmail: true`, `fuzzyIP: false`).
  - Disabled IP-links without schema prefix by default.

* 1.0.1 / 2015-04-19

  - More strict default 2-characters tlds handle in fuzzy links, to avoid
  false positives for `node.js`, `io.js` and so on.
