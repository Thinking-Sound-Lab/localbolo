import { DocPage, type DocSection } from "@/components/doc-page";
import { pageMetadata } from "@/lib/metadata";
import { site } from "@/lib/site";

export const metadata = pageMetadata({
  path: "/refunds",
  title: "Refund policy",
  description: `Ask within ${site.refundDays} days of buying ${site.name} for a full refund.`,
});

const email = <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>;

const sections: DocSection[] = [
  {
    id: "guarantee",
    title: `${site.refundDays} days, no questions asked`,
    content: (
      <p>
        If {site.name} isn&apos;t right for you, email us within {site.refundDays} days of your
        purchase and we&apos;ll refund you in full. You don&apos;t need to give a reason, though
        we&apos;d love to hear it.
      </p>
    ),
  },
  {
    id: "how",
    title: "How to ask",
    content: (
      <p>
        Email {email} from the address you used to buy {site.name}, and include your order number
        from the receipt. We reply to refund requests within a few business days.
      </p>
    ),
  },
  {
    id: "timing",
    title: "When the money arrives",
    content: (
      <p>
        Refunds go back to the payment method you used. Once we&apos;ve issued it, your bank or card
        provider usually takes 5 to 10 business days to show it.
      </p>
    ),
  },
  {
    id: "after",
    title: "After a refund",
    content: (
      <p>
        A refund ends your license, so please delete {site.name} from your Macs. You can remove its
        downloaded models by deleting <code>~/Library/Application Support/LocalBolo</code>.
      </p>
    ),
  },
  {
    id: "rights",
    title: "Your statutory rights",
    content: (
      <p>
        This policy is in addition to any rights you have under the consumer law where you live.
      </p>
    ),
  },
];

export default function RefundsPage() {
  return (
    <DocPage
      eyebrow="Refund policy"
      title="Try it without the risk."
      intro={`Every purchase of ${site.name} comes with a ${site.refundDays}-day refund.`}
      updated="September 28, 2026"
      sections={sections}
    />
  );
}
