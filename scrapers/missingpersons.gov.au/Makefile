# requires ruby 1.9.3 with appropriaet gems to run correctly

missingpersons.clean.csv: missingpersons.scrape.csv missingpersons.clean.rb
	cat $< | ruby $(word $(words $^),$^) > $@

missingpersons.scrape.csv: missingpersons.scrape.rb
	ruby $< > $@
