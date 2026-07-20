import { MarkdownBlock, MarkdownBlockType, MarkdownInlineSegment } from '../../model/AiModels';

export class MarkdownParser {
  private static cleanText(value: string): string {
    const normalized: string = value.split('`').join('').split('<br>').join('\n').split('<br/>').join('\n');
    let result: string = '';
    let insideTag: boolean = false;
    for (let index: number = 0; index < normalized.length; index++) {
      const current: string = normalized.charAt(index);
      if (current === '<') {
        insideTag = true;
      } else if (current === '>' && insideTag) {
        insideTag = false;
      } else if (!insideTag) {
        result += current;
      }
    }
    return result;
  }

  private static numberedContent(line: string): string {
    let index: number = 0;
    while (index < line.length) {
      const code: number = line.charCodeAt(index);
      if (code < 48 || code > 57) break;
      index++;
    }
    if (index > 0 && index + 1 < line.length && line.charAt(index) === '.' && line.charAt(index + 1) === ' ') {
      return line.substring(index + 2).trim();
    }
    return '';
  }

  private static headingLevel(line: string): number {
    if (line.startsWith('### ')) return 3;
    if (line.startsWith('## ')) return 2;
    if (line.startsWith('# ')) return 1;
    return 0;
  }

  private static headingContent(line: string, level: number): string {
    return line.substring(level + 1).trim();
  }

  static parse(markdown: string): MarkdownBlock[] {
    const lines: string[] = MarkdownParser.cleanText(markdown).split('\r').join('').split('\n');
    const blocks: MarkdownBlock[] = [];
    let paragraph: string[] = [];
    let listItems: string[] = [];
    let listType: MarkdownBlockType = MarkdownBlockType.BULLET_LIST;

    const flushParagraph = (): void => {
      if (paragraph.length > 0) {
        blocks.push({
          type: MarkdownBlockType.PARAGRAPH,
          content: paragraph.join('\n'),
          items: [],
          headingLevel: 0
        });
        paragraph = [];
      }
    };
    const flushList = (): void => {
      if (listItems.length > 0) {
        blocks.push({ type: listType, content: '', items: listItems, headingLevel: 0 });
        listItems = [];
      }
    };

    for (let index: number = 0; index < lines.length; index++) {
      const line: string = lines[index].trim();
      if (!line) {
        flushParagraph();
        flushList();
        if (blocks.length > 0 && blocks[blocks.length - 1].type !== MarkdownBlockType.SPACER) {
          blocks.push({ type: MarkdownBlockType.SPACER, content: '', items: [], headingLevel: 0 });
        }
      } else if (line === '---' || line === '***') {
        flushParagraph();
        flushList();
        blocks.push({ type: MarkdownBlockType.DIVIDER, content: '', items: [], headingLevel: 0 });
      } else if (MarkdownParser.headingLevel(line) > 0) {
        const level: number = MarkdownParser.headingLevel(line);
        flushParagraph();
        flushList();
        blocks.push({
          type: MarkdownBlockType.HEADING,
          content: MarkdownParser.headingContent(line, level),
          items: [],
          headingLevel: level
        });
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flushParagraph();
        if (listItems.length > 0 && listType !== MarkdownBlockType.BULLET_LIST) flushList();
        listType = MarkdownBlockType.BULLET_LIST;
        listItems.push(line.substring(2).trim());
      } else {
        const numbered: string = MarkdownParser.numberedContent(line);
        if (numbered) {
          flushParagraph();
          if (listItems.length > 0 && listType !== MarkdownBlockType.NUMBERED_LIST) flushList();
          listType = MarkdownBlockType.NUMBERED_LIST;
          listItems.push(numbered);
        } else {
          flushList();
          paragraph.push(line);
        }
      }
    }
    flushParagraph();
    flushList();
    while (blocks.length > 0 && blocks[blocks.length - 1].type === MarkdownBlockType.SPACER) blocks.pop();
    return blocks;
  }

  static inlineSegments(value: string): MarkdownInlineSegment[] {
    const segments: MarkdownInlineSegment[] = [];
    let cursor: number = 0;
    while (cursor < value.length) {
      const start: number = value.indexOf('**', cursor);
      if (start < 0) {
        segments.push({ text: value.substring(cursor).split('**').join(''), bold: false });
        break;
      }
      if (start > cursor) segments.push({ text: value.substring(cursor, start), bold: false });
      const end: number = value.indexOf('**', start + 2);
      if (end < 0) {
        segments.push({ text: value.substring(start).split('**').join(''), bold: false });
        break;
      }
      const boldText: string = value.substring(start + 2, end);
      if (boldText.length > 0) {
        segments.push({ text: boldText, bold: true });
      }
      cursor = end + 2;
    }
    if (segments.length === 0) segments.push({ text: value.split('**').join(''), bold: false });
    return segments;
  }
}
