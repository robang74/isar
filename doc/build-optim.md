BUILDING OPTIMISATION CHANGELOG
-------------------------------

Building process optimisation starts with a bugfix in do_copy_boot_files (tag: build-optim)
and includes 12 different commits on the branch 'evo' (commit hashes could change, rebase):

* 0da6275 - changes for a faster build using less disk space, changelog
* 1247d5c - bugfix: no sstate archive obtainable, will run full task instead  (branch: evo)
* 00f0ed1 - deb-dl-dir deb_dl/lists_dir_im/export rationalisation
* 891afaf - deb_lists_dir_export always overwrite, keep update lists
* c335f29 - bootstrap im/export apt update lists to fasten the whole procedure
* 310417a - deb-dl-dir deb_lists_dir_im/export added + rationalisation
* 4546782 - changes for a faster build using less disk space, p.5
* 4af6262 - changes for a faster build using less disk space, p.4
* 8c4a0c2 - changes for a faster build using less disk space, p.3
* 02bfafb - changes for a faster build using less disk space, p.2
* 83ce565 - changes for a faster build using less disk space, p.1
* f34aece - bugfix: do_copy_boot_files was able to fail but then set -e  (tag: build-optim)

To verify the building process optimisation in numeric terms, a test has been developed.


Test Suite
----------

This functions were used to make a comparison about the improvement:

* check-build-perform.sh

executing the above script in a second terminal and in the top folder
of your project while on another terminal:

	1$ clean all
    2$ ./check-build-perform.sh
	1$ build basic-os

when complete press a key in the previous terminal to collect data:

	    original           patch 1
	------------ basic-os --------------
	43954 Mb (max)   |  8657 Mb (max)
	26548 Mb (rest)  |  4118 Mb (rest)
	 3741 Mb (deb)   |  3741 Mb (deb)
	  820 Mb (wic)   |   820 Mb (wic)
	11789 Mb (cache) |   579 Mb (cache)
	time: 8m33s      | time: 4m34s

After the changes the max disk size used is 2x downloaded debian packages
plus the size of the wic image and the debootstrap cache:

	2 x 3741 + 820 + 579 = 8881 > 8654 MB

About the building time, it has been reduced by 2x times.


Improvements
------------

	    patch 1         patches 1,2,3
	------------ basic-os --------------
	 8657 Mb (max)   |  4876 Mb (max)
	 4118 Mb (rest)  |  4028 Mb (rest)
	 3741 Mb (deb)   |  3741 Mb (deb)
	  820 Mb (wic)   |   820 Mb (wic)
	  579 Mb (cache) |   550 Mb (cache)
	time: 4m34s      | time: 4m24s

	  patches 1-3        patches 1-4
	------------ basic-os --------------
	 4876 Mb (max)   |  4801 Mb (max)
	 4028 Mb (rest)  |  3952 Mb (rest)
	 3741 Mb (deb)   |  3741 Mb (deb)
	  820 Mb (wic)   |   820 Mb (wic)
	  550 Mb (cache) |   550 Mb (cache)
	time: 4m24s      | time: 4m16s

	    original          patches 1-4
	------------ complete -------------- ======
	52507 Mb (max)   | 29912 Mb (max)    1.76x
	43311 Mb (rest)  | 20716 Mb (rest)   2.09x
	 3741 Mb (deb)   |  3741 Mb (deb)     -
	 9159 Mb (wic)   |  9159 Mb (wic)     -
	11799 Mb (cache) |   560 Mb (cache) 21.07x
	time: 20m13s     | time: 13m14s      1.53x

	    original          patches 1-4
	------------- basic-os -------------- ======
	43954 Mb (max)   |  4801 Mb (max)     9.15x
	26548 Mb (rest)  |  3952 Mb (rest)    6.18x
	 3741 Mb (deb)   |  3741 Mb (deb)      -
	  820 Mb (wic)   |   820 Mb (wic)      -
	11789 Mb (cache) |   550 Mb (cache)  21.43x
	time: 8m33s      | time: 4m16s        2.00x

	 patches 1-4          patches 1-5
	------------ basic-os --------------
	 4801 Mb (max)   |   4711 Mb (max)
	 3952 Mb (rest)  |   3855 Mb (rest)
	 3741 Mb (deb)   |   3742 Mb (deb)
	  820 Mb (wic)   |    820 Mb (wic)
	  550 Mb (cache) |    522 Mb (cache)
	time: 4m16s      | time: 4m15s

Performances normalised over 3763/3741 = 1.006, because the composition of
this image changed due to man/pages addition.

	   original           patches 1-5
	------------- complete ------------- ==============
	52507 Mb (max)    | 29849 Mb (max)    1.77x   2.11x
	43311 Mb (rest)   | 20651 Mb (rest)   2.11x   2.99x
	 3741 Mb (deb)    |  3763 Mb (deb)     -
	 9159 Mb (wic)    |  9161 Mb (wic)     -
	11799 Mb (cache)  |   532 Mb (cache) 22.31x
	time: 20m13s      | time: 13m39s      1.49x

Moreover, the first two ratios should be calculated between the values but
subtracted by the size of the image produced.

	   original           patches 1-5
	------------ basic-os -------------- ==============
	43954 Mb (max)   |  4711 Mb (max)     9.33x  11.09x
	26548 Mb (rest)  |  3855 Mb (rest)    6.89x   8.48x
	 3741 Mb (deb)   |  3742 Mb (deb)      -
	  820 Mb (wic)   |   820 Mb (wic)      -
	11789 Mb (cache) |   522 Mb (cache)  22.58x
	time: 8m33s      | time: 4m15s        2.01x

Overall performances increased by a 2x fold with some clear great
improvements in some specific dimensions (cache size) and cases.

	   original           full set
	------------ basic-os -------------- ==============
	43954 Mb (max)   |  3751 Mb (max)     9.58x  11.45x
	26548 Mb (rest)  |  2747 Mb (rest)    9.66x  13.35x
	 3741 Mb (deb)   |  3887 Mb (deb)      -
	  820 Mb (wic)   |   820 Mb (wic)      -
	11789 Mb (cache) |   522 Mb (cache)  22.58x
	time: 8m33s      | time: 3m27s        2.48x

	   original            full set
	------------- complete ------------- ==============
	52507 Mb (max)    | 29703 Mb (max)    1.77x   2.11x
	43311 Mb (rest)   | 20506 Mb (rest)   2.11x   3.01x
	 3741 Mb (deb)    |  3887 Mb (deb)     -
	 9159 Mb (wic)    |  9161 Mb (wic)     -
	11799 Mb (cache)  |   532 Mb (cache) 22.31x
	time: 20m13s      | time: 12m18s      1.64x


The schroot only
----------------

On the top of the patches listed aboce have been applyed 4 patches to migrate
from buildchroot to schroot by Anton Mikanovich and 12 patches for improvment:

* 5d6baeb - dpkg class sbuild allows extra arguments by vars  (branch: evo2)
* 49788bd - sudo -E chroot ${rootfs} /usr/bin/apt-get -y update, standardisation
* 000d708 - deb_dl_dir_im/export nolists when USE_CCACHE is not active
* 0f95199 - deb-dl-dir deb_dl/lists_dir_im/export rationalisation, p.3

* 0194961 - changes for a faster build using less disk space, p.7  (branch: schroot)
* a8c7ff4 - changes for a faster build using less disk space, p.6
* 3f825bb - sstate cache not anymore CACHEDIR.TAG but tar --exclude
* 8857585 - deb-dl-dir deb_dl/lists_dir_im/export rationalisation, p2
* 22e3b05 - image apt clean buildchroot moved to clean schroot insted
* 632c4ec - image class bugfix: interuption does not break the rebuild
* 9be4304 - image tools ext. class bugfix: interuption does not break the rebuild
* 99817b7 - dpkg base class: use schroot only not buildchroot anymore

* ecfec69 - events: Cleanup lost schroot sessions if any, v2
* efa0994 - imager: Move image types to schroot, v2
* bdb4169 - imager: Migrate from buildchroot to schroot, v2
* 3f26709 - sbuild: Allow setting custom config paths, v2  (tag: schroot-only)

Here summuarised for the two opposite cases, the new results:

          original            full set + schroot only
       ------------ basic-os -------------- ==============
       43954 Mb (max)   |  3500 Mb (max)    12.56x  16.01x
       26548 Mb (rest)  |  2522 Mb (rest)   10.52x  15.12x
        3741 Mb (deb)   |  3887 Mb (deb)      -
         820 Mb (wic)   |   820 Mb (wic)      -
       11789 Mb (cache) |   235 Mb (cache)  50.17x
       time: 8m33s      | time: 3m19s        2.58x

          original            full set + schroot only
       ------------ complete ------------- ==============
       52507 Mb (max)   | 28664 Mb (max)    1.83x   2.22x
       43311 Mb (rest)  | 19345 Mb (rest)   2.24x   3.36x
        3741 Mb (deb)   |  3887 Mb (deb)     -
        9159 Mb (wic)   |  9161 Mb (wic)     -
       11799 Mb (cache) |   245 Mb (cache) 48.16x
       time: 20m13s     | time: 11m57s      1.69x


Rebase in 'rebnext'
-------------------

Due to the great amount of changes, it was required to do a cherry-picking and
rebase process in order to obtaine a more suitable set of patches. This process
is still undergonig. This is the results from the 1st round of code assesment:

From these numbers the first thing we notice is that the size of the deb cache
does not matter at all because 10x more is not slower at all. This makes per-
fectly sense because linking 385 or 1260 does not make such a difference.
       
          full debs           minimal           rebnext
       ------------ basic-os -------------- ==============
        3498 Mb (max)   |  3489 Mb (max)     1.00x   1.00x
        2588 Mb (rest)  |  2587 Mb (rest)    1.00x   1.00x
        3417 Mb (deb)   |   364 Mb (deb)     9.39x
         814 Mb (wic)   |   814 Mb (wic)      -
         273 Mb (cache) |   273 Mb (cache)   1.00x
       time: 3m09s      | time: 3m10s        2.58x
       
Compared to the original the performances increase is impressive, in both cases:

          original           cherries + schroot + rebase
       ------------ basic-os -------------- ==============
       43954 Mb (max)   |  3498 Mb (max)    12.57x  16.07x
       26548 Mb (rest)  |  2588 Mb (rest)   10.26x  14.50x
        3741 Mb (deb)   |  3417 Mb (deb)      -
         820 Mb (wic)   |   814 Mb (wic)      -
       11789 Mb (cache) |   273 Mb (cache)  43.18x
       time: 8m33s      | time: 3m09s        2.71x

          original           cherries + schroot + rebase
       ------------ complete ------------- ===============
       52507 Mb (max)   | 28606 Mb (max)     1.84x   2.23x
       43311 Mb (rest)  | 19413 Mb (rest)    2.23x   3.33x
        3741 Mb (deb)   |  3417 Mb (deb)      -
        9159 Mb (wic)   |  9155 Mb (wic)      -
       11799 Mb (cache) |   283 Mb (cache)  41.69x
       time: 20m13s     | time: 11m44s       1.72x

Considering that the local .deb cache growing with the time because new updates
will be added, and comparing the performance gains between the basic-os and the
complete image, we can say that on the long run also the complete case will 
reach the 2x of performance at least in time building.


