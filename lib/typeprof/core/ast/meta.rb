module TypeProf::Core
  class AST
    class IncludeMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        # TODO: error for splat
        @args = raw_node.arguments.arguments.map do |raw_arg|
          AST.create_node(raw_arg, lenv)
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def subnodes = { args: }

      def define0(genv)
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        @args.each do |arg|
          arg.define(genv)
          if arg.static_ret
            arg.static_ret.followers << mod
            mod.add_include_def(genv, arg)
          end
        end
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        @args.each do |arg|
          if arg.static_ret
            mod.remove_include_def(genv, arg)
          end
          arg.undefine(genv)
        end
        super(genv)
      end

      def install0(genv)
        @args.each {|arg| arg.install(genv) }
        Source.new
      end
    end

    class AttrReaderMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @args = []
        raw_node.arguments.arguments.each do |raw_arg|
          @args << raw_arg.value.to_sym if raw_arg.type == :symbol_node
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def attrs = { args: }

      def req_positionals = []
      def opt_positionals = []
      def post_positionals = []
      def rest_positionals = nil
      def req_keywords = []
      def opt_keywords = []
      def rest_keywords = nil

      def install0(genv)
        @args.each do |arg|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site(:attr_reader, site)
          mdef = MethodDefSite.new(self, genv, @lenv.cref.cpath, false, arg, FormalArguments::Empty, site.ret)
          add_site(:mdef, mdef)
        end
        Source.new
      end
    end

    class AttrAccessorMetaNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @args = []
        raw_node.arguments.arguments.each do |raw_arg|
          @args << raw_arg.value.to_sym if raw_arg.type == :symbol_node
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def attrs = { args: }

      def define0(genv)
        @args.map do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, "@#{ arg }".to_sym)
          mod.add_def(self)
          mod
        end
      end

      def undefine0(genv)
        @args.each do |arg|
          mod = genv.resolve_ivar(lenv.cref.cpath, false, "@#{ arg }".to_sym)
          mod.remove_def(self)
        end
      end

      def install0(genv)
        i = 0
        @args.zip(@static_ret) do |arg, ive|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site(i += 1, site)
          mdef = MethodDefSite.new(self, genv, @lenv.cref.cpath, false, arg, FormalArguments::Empty, site.ret)
          add_site(:mdef, mdef)

          vtx = Vertex.new("attr_writer-arg", self)
          vtx.add_edge(genv, ive.vtx)
          f_args = FormalArguments.new([vtx], [], nil, [], [], [], nil, nil)
          mdef = MethodDefSite.new(self, genv, @lenv.cref.cpath, false, "#{ arg }=".to_sym, f_args, vtx)
          add_site(:mdef, mdef)
        end
        Source.new
      end
    end
  end
end
