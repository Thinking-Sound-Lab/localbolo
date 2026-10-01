import { DocPage, type DocSection } from "@/components/doc-page";
import { releases } from "@/lib/changelog";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/changelog",
  title: "Changelog",
  description: `What's new in each version of ${site.name}.`,
});

const sections: DocSection[] = releases.map((release) => ({
  id: `v${release.version.replaceAll(".", "-")}`,
  title: `${site.name} ${release.version} · ${release.date}`,
  content: (
    <ul>
      {release.changes.map((change) => (
        <li key={change}>{change}</li>
      ))}
    </ul>
  ),
}));

export default function ChangelogPage() {
  return (
    <DocPage
      eyebrow="Changelog"
      title="What's new."
      intro={`Every version of ${site.name}, newest first.`}
      sections={sections}
    />
  );
}
