defmodule PropCheck.TypeGen do
	@moduledoc """
	This module creates type generating functions from type specifications.

	This is Elixir version of PropEr's parse transformation
	"""

	@doc """
	This function lists the types defined in the module. If the module is open (i.e. it is 
	currently compiled) it shall work, but also after the compilation. The first one is required
	for adding type generator functions during compilation, the latter is used for inspecting
	and generating functions for types in a remote defined module (e.g. from the the Standard lib)
	"""

	defmacro __using__(_options) do
		quote do
			# we need the Proper Definitions
			use PropCheck.Properties
			# use the original module
			import unquote(__MODULE__)
			# infer the defined types just before compilation (= code generation)
			# and inject for each type the corresponding generator function
			@before_compile unquote(__MODULE__)
		end
	end

	defmacro __before_compile__(env) do
		#IO.inspect env
		types = env.module 
			|> PropCheck.TypeGen.defined_types
			|> List.flatten
		types
			|> Enum.each &PropCheck.TypeGen.print_types/1
		types 
			|> Enum.map &convert_type/1
		# []	
	end

	def defined_types(mod) do
		if Module.open? mod do
			IO.puts "Module #{mod} is open"
			[:type, :opaque, :typep] 
				|> Enum.map &(Module.get_attribute(mod,&1)) 
		else
			IO.puts "Module #{mod} is closed"
			[beam: Kernel.Typespec.beam_types(mod), attr: mod.__info__()]
		end
	end
	
	def print_types({kind, {:::, _, [lhs, rhs]}, nil, _env}) when kind in [:type, :opaque, :typep] do
		IO.puts "Type definition for #{inspect lhs} ::= #{inspect rhs}"
	end
	def print_types(types) when is_list(types) do
		IO.puts "Types: Got a list with #{length(types)} elements"
	end
	
	@doc "Generates a function for a type definition"
	def convert_type({:typep, {:::, _, typedef}, nil, _env}) do
		header = type_header(typedef)
		body = type_body(typedef)
		quote do
			defp unquote(header) do
				unquote(body)
			end
		end
	end
	def convert_type({kind, {:::, _, typedef}, nil, _env}) when kind in [:type, :opaque] do
		header = type_header(typedef)
		body = type_body(typedef)
		quote do
			def unquote(header) do
				unquote(body)
			end
		end
	end
	
	@doc "Generates the type generator signature"
	def type_header([{name, _, nil}, _rhs]) do 
		quote do 
			unquote(name)()
		end
	end
	def type_header([{name, _, vars} = head, _rhs]) when is_atom(name) do
		head
	end
	
	@doc "Generates a simple body for the type generator function"
	# TODO: build up an environment of parameters to stop the recursion, if they are used
	def type_body([_lhs, rhs]), do: type_body(rhs)
	def type_body({:port, _, _}), do: throw "unsupported type port"
	def type_body({:pid, _, _}), do: throw "unsupported type pid"
	def type_body({:reference, _, _}), do: throw "unsupported type reference"
	def type_body({:atom, _, _}) do quote do atom end end
	def type_body({:any, _, _}) do quote do any end end
	def type_body({:float, _, _}) do quote do float(:inf, :inf) end end
	def type_body({:integer, _, _}) do quote do integer(:inf, :inf) end end
	def type_body({:non_neg_integer, _, _}) do quote do integer(0, :inf) end end
	def type_body({:pos_integer, _, _}) do quote do integer(1, :inf) end end
	def type_body({:.., _, [left, right]}) do quote do integer(unquote(left), unquote(right)) end end
	def type_body({:list, _, nil}) do quote do list(any) end end
	def type_body({:list, _, [type]}) do quote do list(unquote(type_body(type))) end end
	def type_body([type]) do quote do list(unquote(type_body(type))) end end
	def type_body(body) do 
		body_s = "#{inspect body}"
		quote do 
			throw "catch all: no generator available for " <> unquote(body_s) 
		end 
	end

end