# Copyright (C) 2014-2015 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'mongo/operation/read/query'
require 'mongo/operation/read/get_more'
require 'mongo/operation/read/indexes'
require 'mongo/operation/read/list_indexes'
require 'mongo/operation/read/list_collections'
require 'mongo/operation/read/collections_info'

module Mongo
  module Operation
    module Read

      class NoNamespace < OperationError

        def initialize(document)
          super("Namespace does not exist on server: '#{document[ERROR_MSG]}'.")
        end
      end
    end
  end
end