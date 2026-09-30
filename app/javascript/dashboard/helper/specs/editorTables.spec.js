import {
  buildMessageSchema,
  MessageMarkdownTransformer,
  MessageMarkdownSerializer,
} from '@chatwoot/prosemirror-schema';
import {
  withTableNodes,
  parseEditorMarkdown,
  serializeEditorMarkdown,
  hasMarkdownTable,
} from '../editorTables';

const TABLE = '| CAMPOS | RESPOSTA |\n| --- | --- |\n| **Servidor** | Nome |';

describe('editorTables', () => {
  const schema = withTableNodes(
    buildMessageSchema(['strong', 'em', 'link'], ['bulletList', 'image'])
  );

  it('detects a markdown table', () => {
    expect(hasMarkdownTable(TABLE)).toBe(true);
    expect(hasMarkdownTable('texto --- comum')).toBe(false);
  });

  it('parses and serializes a table without losing cells', () => {
    const doc = parseEditorMarkdown(schema, `Olá\n\n${TABLE}`);
    expect(doc.child(1).type.name).toBe('table');
    const markdown = serializeEditorMarkdown(doc);
    expect(markdown).toContain('Olá');
    expect(markdown).toMatch(/\|\s*CAMPOS\s*\|\s*RESPOSTA\s*\|/);
    expect(markdown).toMatch(/\|\s*\*\*Servidor\*\*\s*\|\s*Nome\s*\|/);
  });

  it('reads and writes plain messages exactly like the upstream editor', () => {
    const content = 'linha 1\nlinha 2\n\n- item **forte**';
    const plainSchema = buildMessageSchema(
      ['strong', 'em', 'link'],
      ['bulletList', 'image']
    );
    const upstream = MessageMarkdownSerializer.serialize(
      new MessageMarkdownTransformer(plainSchema).parse(content)
    );
    expect(serializeEditorMarkdown(parseEditorMarkdown(schema, content))).toBe(
      upstream
    );
  });
});
