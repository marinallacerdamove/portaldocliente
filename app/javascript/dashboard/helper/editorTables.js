// PATCH LOCAL (fork) - tabela no editor de resposta (macros importadas do
// Movidesk têm tabela de formulário). O schema de mensagem do
// @chatwoot/prosemirror-schema não tem tabela, então os nós, o parser e o
// serializer de tabela vêm do schema de artigo (Central de Ajuda) do mesmo
// pacote, sem alterar a dependência.
import { Schema } from 'prosemirror-model';
import {
  fullSchema,
  ArticleMarkdownTransformer,
  ArticleMarkdownSerializer,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
} from '@chatwoot/prosemirror-schema';

const TABLE_NODES = ['table', 'table_row', 'table_cell', 'table_header'];

// Linha separadora de tabela markdown (`| --- | --- |`).
const TABLE_DELIMITER =
  /^\s*>?\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$/m;

export const hasMarkdownTable = content =>
  typeof content === 'string' && TABLE_DELIMITER.test(content);

export const withTableNodes = schema => {
  if (schema.nodes.table) return schema;

  const nodes = TABLE_NODES.reduce(
    (spec, name) => spec.addToEnd(name, fullSchema.spec.nodes.get(name)),
    schema.spec.nodes
  );
  return new Schema({ nodes, marks: schema.spec.marks });
};

// O parser de artigo é o único que entende tabela; só entra quando o texto
// tem uma, pra não mudar como as mensagens comuns são lidas.
export const parseEditorMarkdown = (schema, content) => {
  if (schema.nodes.table && hasMarkdownTable(content)) {
    return new ArticleMarkdownTransformer(schema).parse(content);
  }
  return new MessageMarkdownTransformer(schema).parse(content);
};

// prosemirror-markdown não é dependência direta: reusa a classe da instância.
// Criado no primeiro uso (quem mocka o pacote nos specs não tem o serializer).
let tableSerializer;
const getTableSerializer = () => {
  const MarkdownSerializer = MessageMarkdownSerializer.constructor;
  tableSerializer ||= new MarkdownSerializer(
    {
      ...MessageMarkdownSerializer.nodes,
      ...Object.fromEntries(
        TABLE_NODES.map(name => [name, ArticleMarkdownSerializer.nodes[name]])
      ),
    },
    MessageMarkdownSerializer.marks
  );
  return tableSerializer;
};

export const serializeEditorMarkdown = doc =>
  doc.type.schema.nodes.table
    ? getTableSerializer().serialize(doc)
    : MessageMarkdownSerializer.serialize(doc);
