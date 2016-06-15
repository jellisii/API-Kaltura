use strict;
use warnings;
use KalturaAPI;
use Data::Dumper;
use feature qw(say);


my $kt = KalturaAPI->new({
    # secret => 'fdebabc4b60feeb8b53c31b7c24fb634', # user secret
    secret => '4a8756c927df8770c8460214326ead8c', # admin secret
    kalturaUrl => 'https://kmc.kaltura.com',
    apiVersion => 3,
    sessionType => 'admin',
    partnerId => '1963051'
});

die $KalturaAPI::VERSION;

$kt->startSession();

#### Upload a file
#my $upload_result = $kt->uploadFile({
#   file => "/home/eellis/Music/100010429_2.mp3",
#   type => "audio",
#   categoriesIds => "35399081",
#   name => 'Fanfare for the Common Man',
#   description => 'Fanfare for the Common Man, performed by the United States Marine Band.  This entry was downloaded from the United States Library of Congress.',
#   tags => 'audio, music, United States Marine Band',
#   adminTags => 'test data, deleteme'
#});

#### get a user's KMS data.
say $kt->getResult({
    service => 'user',
    action => 'get',
    userId => 'eellis@classroom24-7.com'
})->sprint();

$kt->endSession();
