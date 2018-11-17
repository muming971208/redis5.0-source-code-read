#!/bin/sh
#
# Generate a discrete lookup table for a sigmoid function in the smoothstep
# family (https://en.wikipedia.org/wiki/Smoothstep), where the lookup table
# entries correspond to x in [1/nsteps, 2/nsteps, ..., nsteps/nsteps].  Encode
# the entries using a binary fixed point representation.
#
# Usage: smoothstep.sh <variant> <nsteps> <bfp> <xprec> <yprec>
#
#        <variant> is in {smooth, smoother, smoothest}.
#        <nsteps> must be greater than zero.
#        <bfp> must be in [0..62]; reasonable values are roughly [10..30].
#        <xprec> is x decimal precision.
#        <yprec> is y decimal precision.

#set -x

cmd="sh smoothstep.sh $*"
variant=$1
nsteps=$2
bfp=$3
xprec=$4
yprec=$5

case "${variant}" in
  smooth)
    ;;
  smoother)
    ;;
  smoothest)
    ;;
  *)
    echo "Unsupported variant"
    exit 1
    ;;
esac

smooth() {
  step=$1
  y=`echo ${yprec} k ${step} ${nsteps} / sx _2 lx 3 ^ '*' 3 lx 2 ^ '*' + p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g'`
  h=`echo ${yprec} k 2 ${bfp} ^ ${y} '*' p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g' | tr '.' ' ' | awk '{print $1}' `
}

smoother() {
  step=$1
  y=`echo ${yprec} k ${step} ${nsteps} / sx 6 lx 5 ^ '*' _15 lx 4 ^ '*' + 10 lx 3 ^ '*' + p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g'`
  h=`echo ${yprec} k 2 ${bfp} ^ ${y} '*' p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g' | tr '.' ' ' | awk '{print $1}' `
}

smoothest() {
  step=$1
  y=`echo ${yprec} k ${step} ${nsteps} / sx _20 lx 7 ^ '*' 70 lx 6 ^ '*' + _84 lx 5 ^ '*' + 35 lx 4 ^ '*' + p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g'`
  h=`echo ${yprec} k 2 ${bfp} ^ ${y} '*' p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g' | tr '.' ' ' | awk '{print $1}' `
}

cat <<EOF
#ifndef JEMALLOC_INTERNAL_SMOOTHSTEP_H
#define JEMALLOC_INTERNAL_SMOOTHSTEP_H

/*
 * This file was generated by the following command:
 *   $cmd
 */
/******************************************************************************/

/*
 * This header defines a precomputed table based on the smoothstep family of
 * sigmoidal curves (https://en.wikipedia.org/wiki/Smoothstep) that grow from 0
 * to 1 in 0 <= x <= 1.  The table is stored as integer fixed point values so
 * that floating point math can be avoided.
 *
 *                      3     2
 *   smoothstep(x) = -2x  + 3x
 *
 *                       5      4      3
 *   smootherstep(x) = 6x  - 15x  + 10x
 *
 *                          7      6      5      4
 *   smootheststep(x) = -20x  + 70x  - 84x  + 35x
 */

#define SMOOTHSTEP_VARIANT	"${variant}"
#define SMOOTHSTEP_NSTEPS	${nsteps}
#define SMOOTHSTEP_BFP		${bfp}
#define SMOOTHSTEP \\
 /* STEP(step, h,                            x,     y) */ \\
EOF

s=1
while [ $s -le $nsteps ] ; do
  $variant ${s}
  x=`echo ${xprec} k ${s} ${nsteps} / p | dc | tr -d '\\\\\n' | sed -e 's#^\.#0.#g'`
  printf '    STEP(%4d, UINT64_C(0x%016x), %s, %s) \\\n' ${s} ${h} ${x} ${y}

  s=$((s+1))
done
echo

cat <<EOF
#endif /* JEMALLOC_INTERNAL_SMOOTHSTEP_H */
EOF
