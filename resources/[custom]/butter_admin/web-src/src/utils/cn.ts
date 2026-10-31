/** Joins the truthy class names. */
export function cn(...inputs: (string | false | null | undefined)[]) {
  return inputs
    .filter((input): input is string => !!input)
    .map((input) => input.trim())
    .join(' ');
}
