# *******************************************************************************************
# *******************************************************************************************
#
#		Name : 		mkzip.py
#		Purpose :	Write a zip archive reproducibly.
#		Date :		13th July 2026
#
# *******************************************************************************************
# *******************************************************************************************
#
#		zipfile stamps every member with its mtime, so re-zipping byte-identical content
#		still yields a byte-different archive. That made bin/tokenise.zip, testing/blitz.zip
#		and source/tools/tokenise/tokenise.zip show up as modified after every single build,
#		which buried real changes in the diff. Pinning the timestamp, the member order and
#		the permission bits makes the archive a pure function of its inputs.
#
#		Also replaces zip(1), which is not present on a stock Windows box.
#
#			python mkzip.py <out.zip> <file> [file ...]
#
# *******************************************************************************************

import os, sys, zipfile

#
#		Earliest timestamp the zip format can represent. Any fixed value works; this one
#		is conventional and makes it obvious the stamp is deliberate rather than real.
#
FIXED_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def make_zip(target, sources):
	#
	#		Never swallow the archive we are writing (the release target zips a whole
	#		directory with a glob, which would otherwise pick up a stale blitz.zip).
	#
	target_real = os.path.realpath(target)
	members = sorted(s for s in sources
	                 if os.path.isfile(s) and os.path.realpath(s) != target_real)

	with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as z:
		for source in members:
			info = zipfile.ZipInfo(os.path.basename(source), date_time=FIXED_TIMESTAMP)
			info.compress_type = zipfile.ZIP_DEFLATED
			info.external_attr = 0o644 << 16
			with open(source, "rb") as handle:
				z.writestr(info, handle.read())


if __name__ == "__main__":
	if len(sys.argv) < 3:
		sys.stderr.write("python mkzip.py <out.zip> <file> [file ...]\n")
		sys.exit(-1)
	make_zip(sys.argv[1], sys.argv[2:])
