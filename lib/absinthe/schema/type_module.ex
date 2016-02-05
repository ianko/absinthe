defmodule Absinthe.Schema.TypeModule do
  alias Absinthe.Utils

  defmacro __using__(opts) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :absinthe_errors, accumulate: true
      Module.register_attribute __MODULE__, :absinthe_types, accumulate: true
      Module.register_attribute __MODULE__, :absinthe_exports, accumulate: true
      @before_compile unquote(__MODULE__)
      @after_compile unquote(__MODULE__)
      @doc nil
    end
  end

  defmacro __before_compile__(_env) do
    quote do

      def __absinthe_type__(_), do: nil

      @absinthe_type_map Enum.into(@absinthe_types, %{})
      def __absinthe_types__, do: @absinthe_type_map

      def __absinthe_errors__, do: @absinthe_errors

      def __absinthe_exports__, do: @absinthe_exports

    end
  end

  def __after_compile__(env, _bytecode) do
    case env.module.__absinthe_errors__ do
      [] ->
        nil
      problems ->
        raise Absinthe.Schema.Error, problems
    end
  end

  defmacro object(identifier, blueprint, opts \\ []) do
    naming = type_naming(identifier)
    ast = Absinthe.Type.Object.build(naming, expand(blueprint, __CALLER__))
    define_type(naming, ast, opts)
  end

  defmacro scalar(identifier, blueprint) do
    naming = type_naming(identifier)
    ast = Absinthe.Type.Scalar.build(naming, expand(blueprint, __CALLER__))
    define_type(naming, ast)
  end

  defmacro interface(identifier, blueprint) do
  end

  defmacro input_object(identifier, blueprint) do
  end

  defmacro union(identifier, blueprint) do
  end

  defmacro import_types(type_module_ast, opts_ast \\ []) do
    opts = Macro.expand(opts_ast, __CALLER__)
    type_module = Macro.expand(type_module_ast, __CALLER__)
    for {ident, _} = naming <- type_module.__absinthe_types__, into: [] do
      if Enum.member?(type_module.__absinthe_exports__, ident) do
        ast = quote do
          unquote(type_module).__absinthe_type__(unquote(ident))
        end
        define_type([naming], ast, opts)
      end
    end
  end

  defp expand(ast, env) do
    Macro.postwalk(ast, fn
      {_, _, _} = node -> Macro.expand(node, env)
      node -> node
    end)
  end

  defp type_naming([{_identifier, _name}] = as_defined) do
    as_defined
  end
  defp type_naming(identifier) do
    [{identifier, Utils.camelize_lower(Atom.to_string(identifier))}]
  end

  defp define_type([{identifier, name}] = naming, ast, opts \\ []) do
    quote do
      @absinthe_doc @doc
      type_status = {
        Keyword.has_key?(@absinthe_types, unquote(identifier)),
        Enum.member?(Keyword.values(@absinthe_types), unquote(name))
      }
      if match?({true, _}, type_status) do
        @absinthe_errors %{
          name: :dup_ident,
          location: %{file: __ENV__.file, line: __ENV__.line},
          data: unquote(identifier)
        }
      end
      if match?({_, true}, type_status) do
        @absinthe_errors %{
          name: :dup_name,
          location: %{file: __ENV__.file, line: __ENV__.line},
          data: unquote(name)
        }
      end
      if match?({false, false}, type_status) do
        @absinthe_types {unquote(identifier), unquote(name)}
        if Keyword.get(unquote(opts), :export, true) do
          @absinthe_exports unquote(identifier)
        end
        def __absinthe_type__(unquote(name)) do
          unquote(ast)
        end
        def __absinthe_type__(unquote(identifier)) do
          unquote(ast)
        end
      end
    end
  end

  defmacro deprecate(node, options \\ []) do
    node
  end

  defmacro non_null(type) do
    quote do: %Absinthe.Type.NonNull{of_type: unquote(type)}
  end

  defmacro list_of(type) do
    quote do: %Absinthe.Type.List{of_type: unquote(type)}
  end

end
