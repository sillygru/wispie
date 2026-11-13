pub fn sort_by_key(indices: &mut [usize], keys: &[i64]) {
    do_sort(indices, 0, indices.len() as isize - 1, keys);
}

fn compare(left: usize, right: usize, keys: &[i64]) -> i8 {
    match keys[left].cmp(&keys[right]) {
        std::cmp::Ordering::Less => -1,
        std::cmp::Ordering::Equal => 0,
        std::cmp::Ordering::Greater => 1,
    }
}

fn do_sort(values: &mut [usize], left: isize, right: isize, keys: &[i64]) {
    if right - left <= 32 {
        insertion_sort(values, left, right, keys);
    } else {
        dual_pivot_quicksort(values, left, right, keys);
    }
}

fn insertion_sort(values: &mut [usize], left: isize, right: isize, keys: &[i64]) {
    for i in left + 1..=right {
        let element = values[i as usize];
        let mut j = i;
        while j > left && compare(values[(j - 1) as usize], element, keys) > 0 {
            values[j as usize] = values[(j - 1) as usize];
            j -= 1;
        }
        values[j as usize] = element;
    }
}

fn dual_pivot_quicksort(values: &mut [usize], left: isize, right: isize, keys: &[i64]) {
    let sixth = (right - left + 1) / 6;
    let index1 = left + sixth;
    let index5 = right - sixth;
    let index3 = (left + right) / 2;
    let index2 = index3 - sixth;
    let index4 = index3 + sixth;

    let mut el1 = values[index1 as usize];
    let mut el2 = values[index2 as usize];
    let mut el3 = values[index3 as usize];
    let mut el4 = values[index4 as usize];
    let mut el5 = values[index5 as usize];

    if compare(el1, el2, keys) > 0 {
        std::mem::swap(&mut el1, &mut el2);
    }
    if compare(el4, el5, keys) > 0 {
        std::mem::swap(&mut el4, &mut el5);
    }
    if compare(el1, el3, keys) > 0 {
        std::mem::swap(&mut el1, &mut el3);
    }
    if compare(el2, el3, keys) > 0 {
        std::mem::swap(&mut el2, &mut el3);
    }
    if compare(el1, el4, keys) > 0 {
        std::mem::swap(&mut el1, &mut el4);
    }
    if compare(el3, el4, keys) > 0 {
        std::mem::swap(&mut el3, &mut el4);
    }
    if compare(el2, el5, keys) > 0 {
        std::mem::swap(&mut el2, &mut el5);
    }
    if compare(el2, el3, keys) > 0 {
        std::mem::swap(&mut el2, &mut el3);
    }
    if compare(el4, el5, keys) > 0 {
        std::mem::swap(&mut el4, &mut el5);
    }

    let pivot1 = el2;
    let pivot2 = el4;
    values[index1 as usize] = el1;
    values[index3 as usize] = el3;
    values[index5 as usize] = el5;
    values[index2 as usize] = values[left as usize];
    values[index4 as usize] = values[right as usize];

    let mut less = left + 1;
    let mut great = right - 1;
    let pivots_are_equal = compare(pivot1, pivot2, keys) == 0;

    if pivots_are_equal {
        let pivot = pivot1;
        let mut k = less;
        while k <= great {
            let ak = values[k as usize];
            let mut comp = compare(ak, pivot, keys);
            if comp == 0 {
                k += 1;
                continue;
            }
            if comp < 0 {
                if k != less {
                    values[k as usize] = values[less as usize];
                    values[less as usize] = ak;
                }
                less += 1;
            } else {
                loop {
                    comp = compare(values[great as usize], pivot, keys);
                    if comp > 0 {
                        great -= 1;
                        continue;
                    } else if comp < 0 {
                        let great_value = values[great as usize];
                        values[k as usize] = values[less as usize];
                        values[less as usize] = great_value;
                        values[great as usize] = ak;
                        less += 1;
                        great -= 1;
                        break;
                    } else {
                        values[k as usize] = values[great as usize];
                        values[great as usize] = ak;
                        great -= 1;
                        break;
                    }
                }
            }
            k += 1;
        }
    } else {
        let mut k = less;
        while k <= great {
            let ak = values[k as usize];
            let comp_pivot1 = compare(ak, pivot1, keys);
            if comp_pivot1 < 0 {
                if k != less {
                    values[k as usize] = values[less as usize];
                    values[less as usize] = ak;
                }
                less += 1;
            } else {
                let comp_pivot2 = compare(ak, pivot2, keys);
                if comp_pivot2 > 0 {
                    loop {
                        let comp = compare(values[great as usize], pivot2, keys);
                        if comp > 0 {
                            great -= 1;
                            if great < k {
                                break;
                            }
                            continue;
                        }
                        let comp = compare(values[great as usize], pivot1, keys);
                        if comp < 0 {
                            let great_value = values[great as usize];
                            values[k as usize] = values[less as usize];
                            values[less as usize] = great_value;
                            values[great as usize] = ak;
                            less += 1;
                            great -= 1;
                        } else {
                            values[k as usize] = values[great as usize];
                            values[great as usize] = ak;
                            great -= 1;
                        }
                        break;
                    }
                }
            }
            k += 1;
        }
    }

    values[left as usize] = values[(less - 1) as usize];
    values[(less - 1) as usize] = pivot1;
    values[right as usize] = values[(great + 1) as usize];
    values[(great + 1) as usize] = pivot2;

    do_sort(values, left, less - 2, keys);
    do_sort(values, great + 2, right, keys);
    if pivots_are_equal {
        return;
    }

    if less < index1 && great > index5 {
        while compare(values[less as usize], pivot1, keys) == 0 {
            less += 1;
        }
        while compare(values[great as usize], pivot2, keys) == 0 {
            great -= 1;
        }

        let mut k = less;
        while k <= great {
            let ak = values[k as usize];
            let comp_pivot1 = compare(ak, pivot1, keys);
            if comp_pivot1 == 0 {
                if k != less {
                    values[k as usize] = values[less as usize];
                    values[less as usize] = ak;
                }
                less += 1;
            } else if compare(ak, pivot2, keys) == 0 {
                loop {
                    let comp = compare(values[great as usize], pivot2, keys);
                    if comp == 0 {
                        great -= 1;
                        if great < k {
                            break;
                        }
                        continue;
                    }
                    let comp = compare(values[great as usize], pivot1, keys);
                    if comp < 0 {
                        let great_value = values[great as usize];
                        values[k as usize] = values[less as usize];
                        values[less as usize] = great_value;
                        values[great as usize] = ak;
                        less += 1;
                        great -= 1;
                    } else {
                        values[k as usize] = values[great as usize];
                        values[great as usize] = ak;
                        great -= 1;
                    }
                    break;
                }
            }
            k += 1;
        }
        do_sort(values, less, great, keys);
    } else {
        do_sort(values, less, great, keys);
    }
}
