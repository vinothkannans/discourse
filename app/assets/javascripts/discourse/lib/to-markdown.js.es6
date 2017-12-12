import parseHTML from 'discourse/helpers/parse-html';

String.prototype.trimLeft = function() {
    return this.replace(/^\s+/,"");
}

const Tag = Ember.Object.extend({

  decorate(text) {
    if (this.prefix || this.suffix) {
      return [this.prefix, text, this.suffix].join("");
    }

    return text;
  },

  innerMarkdown() {
    let text = this.element.innerMarkdown();

    if (!["li"].includes(this.element.name)) {
      text = text.replace(/^ +/g, "");
    }

    return text;
  },

  toMarkdown() {
    const text = this.innerMarkdown();

    if (text && text.trim()) {
      return this.decorate(text);
    }

    return text;
  }
});

Tag.reopenClass({

  heading(name, prefix) {
    return Tag.extend({
      name: name,
      prefix: `\n\n${prefix} `,
      suffix: "\n\n",
    });
  },

  emphasis(name, decorator) {
    return Tag.extend({name: name, prefix: decorator, suffix: decorator});
  },

  replace(name, text) {
    return Tag.extend({
      name: name,
      text: text,

      toMarkdown() {
        return this.text;
      }
    });
  },

  separator(name, text) {
    return Tag.replace(name, text);
  },

  region(name) {
    return Tag.extend({name: name, prefix: "\n\n", suffix: "\n\n"});
  },

  link() {
    return Tag.extend({
      name: "a",

      decorate(text) {
        const attr = this.element.attributes;

        if (!text) {
          return "";
        } else if (attr && attr.href && text !== attr.href) {
          return "[" + text + "](" + attr.href + ")";
        }

        return text;
      }

    });
  },

  listItem() {
    return Tag.extend({
      name: "li",
      suffix: "\n",

      decorate(text) {
        const indent = this.element.filterParentNames("li").map(() => "  ").join("");
        if (!this.element.next) {
          this.suffix = "";
        }
        return `${indent}* ${text.trimLeft()}${this.suffix}`;
      }

    });
  }

});

const tags = [
  Tag.heading("h1", "#"),
  Tag.heading("h2", "##"),
  Tag.heading("h3", "###"),
  Tag.heading("h4", "####"),
  Tag.heading("h5", "#####"),
  Tag.heading("h6", "######"),

  Tag.emphasis("b", "**"), Tag.emphasis("strong", "**"),
  Tag.emphasis("i", "_"), Tag.emphasis("em", "_"),
  Tag.emphasis("s", "~~"), Tag.emphasis("strike", "~~"),

  Tag.region("p"), Tag.region("div"),, Tag.region("table"),
  Tag.region("ul"), Tag.region("ol"), Tag.region("dl"),

  Tag.listItem(),

  Tag.separator("br", "\n"),
  Tag.separator("hr", "\n---\n"),

  Tag.link(),

  Tag.replace("head", ""),

  // TODO: img, pre, code, dt, dd, thead, tbody, tr, th, td, ins, del, blockquote
];

const DOMElement = Ember.Object.extend({
  parentNames: [],

  setRelations(parent, previous, next) {
    if (parent) {
      this.parent = parent;
      this.parentNames = parent.parentNames.slice();
      this.parentNames.push(parent.name);
    }
    this.previous = previous;
    this.next = next;
  },

  tag() {
    const tag = tags.filter(t => (t.create().name === this.name))[0] || Tag;
    return tag.create({element: this});
  },

  innerMarkdown() {
    return DOMElement.parseChildren(this);
  },

  toMarkdown() {
    switch(this.type) {
      case "text":
        return this.data;
        break;
      case "tag":
        return this.tag().toMarkdown();
        break;
    }
  },

  isInside(name) {
    return this.name === name || this.filterParentNames(name)[0];
  },

  filterParentNames(name) {
    return this.parentNames.filter(p => p === name);
  }
});

DOMElement.reopenClass({

  toMarkdown(element, parent, prev, next) {
    const el = DOMElement.create(element);
    el.setRelations(parent, prev, next);
    return el.toMarkdown();
  },

  parseChildren(parent) {
    return DOMElement.parse(parent.children, parent);
  },

  parse(elements, parent = null) {
    if (elements) {
      let result = [];

      for (let i = 0; i < elements.length; i++) {
        const prev = (i === 0) ? null : elements[i-1];
        const next = (i === elements.length) ? null : elements[i+1];

        result.push(DOMElement.toMarkdown(elements[i], parent, prev, next));
      }

      return result.join("");
    }

    return "";
  }

});

export default function toMarkdown(html) {
  let markdown = DOMElement.parse(parseHTML(html)).trim();
  return markdown.replace(/\r/g, "").replace(/\n{4,}/g, "\n\n\n");
}
