#
#--
# Copyright (c) 2007-2008, John Mettraux, OpenWFE.org
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
# . Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.  
# 
# . Redistributions in binary form must reproduce the above copyright notice, 
#   this list of conditions and the following disclaimer in the documentation 
#   and/or other materials provided with the distribution.
# 
# . Neither the name of the "OpenWFE" nor the names of its contributors may be
#   used to endorse or promote products derived from this software without
#   specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.
#++
#

#
# "made in Japan"
#
# John Mettraux at openwfe.org
#

#
# this participant requires the twitter4r gem
#
# http://rubyforge.org/projects/twitter4r/
#
# atom-tools' license is X11/MIT
#

#require 'rubygems'
#gem 'twitter4r', '0.2.3'
require 'twitter' # gem 'twitter4r'

require 'openwfe/utils'
require 'openwfe/participants/participant'


module OpenWFE
module Extras

    #
    # Sometimes email is a bit too heavy for notification, this participant
    # emit messages via a twitter account.
    #
    # By default, the message emitted is the value of the field
    # "twitter_message", but this behaviour can be changed by overriding
    # the extract_message() method.
    #
    # If the extract_message doesn't find a message, the message will
    # be the result of the default_message method call, of course this
    # method is overridable as well.
    #
    class TwitterParticipant
        include OpenWFE::LocalParticipant

        #
        # The actual twitter4r client instance.
        #
        attr_accessor :client

        #
        # Keeping the initialization params at hand (if any)
        #
        attr_accessor :params

        #
        # This participant expects a login (twitter user name) and a password.
        #
        # The only optional param for now is :no_ssl, which you can set to
        # true if you want the connection to twitter to not use SSL.
        # (seems like the Twitter SSL service is available less often
        # than the plain http one).
        #
        def initialize (login, password, params={})

            super()

            Twitter::Client.configure do |conf|
                conf.protocol = :http
                conf.port = 80
            end if params[:no_ssl] == true

            @client = Twitter::Client.new(
                :login => login,
                :password => password)

            @params = params
        end

        #
        # The method called by the engine when a workitem for this
        # participant is available.
        #
        def consume (workitem)

            user, tmessage = extract_message workitem

            tmessage = default_message(workitem) unless tmessage

            begin

                if user
                    #
                    # direct message
                    #
                    tuser = @client.user user.to_s
                    @client.message :post, tmessage, tuser
                else
                    #
                    # just the classical status
                    #
                    @client.status :post, tmessage
                end

            rescue Exception => e

                linfo do 
                    "consume() not emitted twitter, because of " +
                    OpenWFE::exception_to_s(e)
                end
            end

            reply_to_engine(workitem) if @application_context
        end

        protected

            #
            # Returns a pair : the target user (twitter login name) 
            # and the message (or status message if there is no target user) to
            # send to Twitter.
            #
            # This default implementation returns a pair composed with the 
            # values of the field 'twitter_target' and of the field 
            # 'twitter_message'.
            #
            def extract_message (workitem)

                [ workitem.attributes['twitter_target'], 
                  workitem.attributes['twitter_message'] ]
            end

            #
            # Returns the default message (called when the extract_message
            # returned nil as the second element of its pair).
            #
            # This default implementation simply returns the workitem 
            # FlowExpressionId instance in its to_s() representation.
            #
            def default_message (workitem)

                workitem.fei.to_s
            end
    end

end
end

