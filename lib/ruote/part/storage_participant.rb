#--
# Copyright (c) 2005-2010, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
# Made in Japan.
#++

require 'ruote/part/local_participant'


module Ruote

  #
  # A participant that stores the workitem in the same storage used by the
  # engine and the worker(s).
  #
  # Does not thread by default.
  #
  class StorageParticipant

    include LocalParticipant
    include Enumerable

    attr_accessor :context

    def initialize (engine_or_options={}, options=nil)

      if engine_or_options.respond_to?(:context)
        @context = engine_or_options.context
      else
        options = engine_or_options
      end

      options ||= {}

      @store_name = options['store_name']
    end

    # No need for a separate thread when delivering to this participant.
    #
    def do_not_thread; true; end

    def consume (workitem)

      doc = workitem.to_h

      doc.merge!(
        'type' => 'workitems',
        '_id' => to_id(doc['fei']),
        'participant_name' => doc['participant_name'],
        'wfid' => doc['fei']['wfid'])

      doc['store_name'] = @store_name if @store_name

      @context.storage.put(doc)
    end
    alias :update :consume

    # Removes the document/workitem from the storage
    #
    def cancel (fei, flavour)

      doc = fetch(fei.to_h)

      r = @context.storage.delete(doc)

      cancel(fei, flavour) if r != nil
    end

    def [] (fei)

      doc = fetch(fei)

      doc ? Ruote::Workitem.new(doc) : nil
    end

    def fetch (fei)

      fei = fei.to_h if fei.respond_to?(:to_h)

      @context.storage.get('workitems', to_id(fei))
    end

    # Removes the workitem from the in-memory hash and replies to the engine.
    #
    def reply (workitem)

      doc = fetch(workitem.fei.to_h)

      r = @context.storage.delete(doc)

      return reply(workitem) if r != nil

      workitem.h.delete('_rev')

      reply_to_engine(workitem)
    end

    # Returns the count of workitems stored in this participant.
    #
    def size

      fetch_all.size
    end

    # Iterates over the workitems stored in here.
    #
    def each (&block)

      all.each { |wi| block.call(wi) }
    end

    # Returns all the workitems stored in here.
    #
    def all

      fetch_all.map { |hwi| Ruote::Workitem.new(hwi) }
    end

    # A convenience method (especially when testing), returns the first
    # (only ?) workitem in the participant.
    #
    def first

      hwi = fetch_all.first

      hwi ? Ruote::Workitem.new(hwi) : nil
    end

    # Return all workitems for the specified wfid
    #
    def by_wfid( wfid )

      @context.storage.get_many('workitems', /!#{wfid}$/).map { |hwi| Ruote::Workitem.new(hwi) }
    end

    # Returns all workitems for the specified participant name
    #
    def by_participant (participant_name)


      hwis = if @context.storage.respond_to?(:by_participant)

        @context.storage.by_participant('workitems', participant_name)

      else

        fetch_all.select { |wi| wi['participant_name'] == participant_name }
      end

      hwis.collect { |hwi| Ruote::Workitem.new(hwi) }
    end

    # field : returns all the workitems with the given field name present.
    #
    # field and value : returns all the workitems with the given field name
    # and the given value for that field.
    #
    # Warning : only some storages are optimized for such queries (like
    # CouchStorage), the others will load all the workitems and then filter
    # them.
    #
    def by_field (field, value=nil)

      hwis = if @context.storage.respond_to?(:by_field)

        @context.storage.by_field('workitems', field, value)

      else

        fetch_all.select { |hwi|
          hwi['fields'].keys.include?(field) &&
          (value.nil? || hwi['fields'][field] == value)
        }
      end

      hwis.collect { |hwi| Ruote::Workitem.new(hwi) }
    end

    # Cleans this participant out completely
    #
    def purge!

      fetch_all.each { |hwi| @context.storage.delete( hwi ) }
    end

    protected

    def fetch_all

      key = @store_name ? /^wi!#{@store_name}::/ : nil

      @context.storage.get_many('workitems', key)
    end

    def to_id (fei)

      a = [ Ruote.to_storage_id(fei) ]

      a.unshift(@store_name) if @store_name

      a.unshift('wi')

      a.join('!')
    end
  end
end

