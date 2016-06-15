package API::Kaltura::CuePoint;
use strict;
use warnings;

BEGIN {
    our ($VERSION, %TYPE);
    %TYPE = {
        AD => 'adCuePoint.Ad',
        ANNOTATION => 'annotation.Annotation',
        CODE => 'codeCuePoint.Code',
        EVENT => 'eventCuePoint.Event',
        QUIZ_ANSWER => 'quiz.QUIZ_ANSWER',
        QUIZ_QUESTION => 'quiz.QUIZ_QUESTION',
        THUMB => 'thumbCuePoint.Thumb'
    }
}
