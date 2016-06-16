# NAME

API::Kaltura - Kaltura API utility.

# VERSION

0.03

# SYNOPSIS

    use API::Kaltura;
    my $kt = API::Kaltura->new({
        secret => 'my secret from Kaltura',
        kalturaUrl => 'https://my.kaltura.url',
        apiVersion => 3,
        sessionType => 'admin', # admin or user only
        partnerId => '1234567890'
    });
    $kt->start_session();
    
    # getResult will be the most commonly used function.
    # get a user's KMS data.
    $user_twig = $kt->get_result({
        service => 'user',
        action => 'get',
        userId => 'someUserId'
    });
    
    # To get the raw L<LWP::UserAgent|LWP::UserAgent> object from Kaltura, you 
    # can use run_service.  This can be useful for troubleshooting problems.
    my $ua = $kt->run_service({
        service => 'user',
        action => 'get',
        userId => 'someUserId'
    });
    
    # Upload a file.  This is considered experimental as error catching
    # is not that great currently.
    my $upload_result = $kt->upload_file({
        file => "/path/to/a/file",
        type => "audio", # see Kaltura API info for valid types.
        categoriesIds => '1234567890',
        name => 'Name for this media',
        description => 'Description for this media',
        tags => 'comma, separated, tags',
        adminTags => 'comma, separated, tags'
    });
    
    # Kill the existing session.
    $kt->endSession();

# DESCRIPTION

Easy low-level access to Kaltura API functions.

# USAGE

Documentation for services and actions can be found on Kaltura's website.
The simplest usage of this module is as documented in the synopsis.

# SUBROUTINES/METHODS

## $kt = API::Kaltura->new($hashref)

Bootstraps a new instance of API::Kaltura.  The following are all
required.

- secret

    A secret.  This is provided by your KMC/Kaltura.    

- kalturaUrl

    The URL of your Kaltura instance.

- apiVersion

    Version of the API to use.  As of this writing, only 3 is supported.

- sessionType

    Kaltura session type.  As of this writing, admin or user are the only
    supported session types.

- partnerId

    Partner ID.  This is provided by your KMC/Kaltura.

## $kt->start\_session()

Starts a Kaltura Session.  Returns true if successful.

Currently, session lengths are defined by the server.  There is a TODO to
be able to pass a session length with this method.

## $kt->get\_result($hashref)

Gets the results of a specified request.  Returns an XML::Twig object. The
following are required:

- service

    The service to be used.

- action

    The action on the service.

Most actions have other requirements as well.  See the Kaltura API
documentation for more details

## $kt->run\_service($hashref)

This method has the same requirements as get\_result.  The only difference
is that it returns a LWP object.  This method is envisioned to primarily
be used for troubleshooting API access.

## $kt->upload\_file($hashref)

**This method is considered experimental.  It probably will change.**

This method wraps up all the calls required to upload a file into the
Kaltura instance.  Returns an XML::Twig object.  The following are required.

- file

    A file to be uploaded.  This should be something media-ish, but Kaltura
    will ingest almost anything.  

## $kt->end\_session()

Kills the existing session being used by the API::Kaltura object.  

# DEPENDENCIES

[XML::Twig](https://metacpan.org/pod/XML::Twig), [LWP](https://metacpan.org/pod/LWP)

# BUGS AND LIMITATIONS

Probably lots.  All undocumented.  May $DEITY have mercy upon you.

This API is woefully incomplete when compared to the other options that
are available from Kaltura.  

# SUPPORT

For Kaltura, refer to your account rep or the Kaltura documentation and
forums.
For this module, please contact the author.

# AUTHOR

J. Eric Ellis

CPAN ID: JELLISII

jellisii@gmail.com

# LICENSE AND COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.
The full text of the license can be found in the
LICENSE file included with this module.

# SEE ALSO

perl(1), [XML::Twig](https://metacpan.org/pod/XML::Twig), [LWP](https://metacpan.org/pod/LWP),
[www.kaltura.com](https://www.kaltura.com)
